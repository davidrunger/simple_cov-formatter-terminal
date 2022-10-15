# frozen_string_literal: true

RSpec.describe SimpleCov::Formatter::Terminal do
  subject(:formatter) { SimpleCov::Formatter::Terminal.new }

  around do |example|
    ClimateControl.modify(SIMPLECOV_WRITE_TARGET_TO_FILE: nil) do
      example.run
    end
  end

  before { allow(formatter).to receive(:write_target_info_file) } # don't actually write to file

  describe '::_setup_rspec' do
    subject(:_setup_rspec) { SimpleCov::Formatter::Terminal.send(:_setup_rspec) }

    it 'calls the expected methods' do
      expect(RSpec).to receive(:configure) do |&block|
        double = instance_double(RSpec::Core::Configuration)

        expect(double).to receive(:before).with(:suite).and_yield

        expect(double).to receive(:after).with(:suite) do |&after_block|
          rspec_example_double =
            instance_double(
              RSpec::Core::Example,
              exception: StandardError.new,
              file_path: './spec/models/user.rb',
            )

          expect(RSpec.world).
            to receive(:filtered_examples).
            and_return({ 'irrelevant_key' => rspec_example_double })

          after_block.call

          SimpleCov::Formatter::Terminal.failure_occurred = false
        end

        block.call(double)
      end

      _setup_rspec
    end
  end

  describe '#format' do
    subject(:format) { formatter.format(result) }

    let(:result) { instance_double(SimpleCov::Result) }

    context 'when no specs have been successfully executed' do
      before do
        expect(SimpleCov::Formatter::Terminal).
          to receive(:executed_spec_files).
          and_return(nil)
      end

      it 'prints a message about no specs having been executed' do
        expect(formatter).to receive(:puts).with(/no specs were executed successfully/)
        format
      end
    end

    context 'when a targeted application file cannot be determined' do
      before { expect(formatter).to receive(:targeted_application_file).and_return(nil) }

      it 'prints the appropriate info' do
        expect(formatter).to receive(:print_info_for_undetermined_application_target)
        format
      end
    end

    context 'when the "targeted application file" does not actually exist' do
      before do
        expect(formatter).
          to receive(:targeted_application_file).
          at_least(:once).
          and_return('not/there.rb')
      end

      it 'prints the appropriate info' do
        expect(formatter).to receive(:print_info_for_nonexistent_application_target)
        format
      end
    end

    context 'when the targeted application file exists' do
      before do
        expect(formatter).
          to receive(:targeted_application_file).
          at_least(:once).
          and_return(targeted_application_file)

        expect(result).to receive(:files).and_return(files)
      end

      let(:targeted_application_file) { 'lib/simple_cov/formatter/terminal.rb' }
      let(:files) { [SimpleCov::SourceFile.new(targeted_application_file, coverage_data)] }
      let(:coverage_data) do
        { 'lines' => [] }
      end

      context 'when there is no coverage info about the targeted file' do
        let(:files) { [SimpleCov::SourceFile.new('app/not/the/target/file.rb', coverage_data)] }

        it 'prints that no coverage info was found' do
          expect(formatter).to receive(:puts).with(/No code coverage info was found/)
          format
        end
      end

      context 'when a test failure failure occurred' do
        around do |spec|
          SimpleCov::Formatter::Terminal.failure_occurred = true
          spec.run
          SimpleCov::Formatter::Terminal.failure_occurred = false
        end

        context 'when SIMPLECOV_FORCE_DETAILS env var is not set' do
          around do |example|
            ClimateControl.modify(SIMPLECOV_FORCE_DETAILS: nil) do
              example.run
            end
          end

          it 'does not print coverage details' do
            expect(formatter).not_to receive(:print_coverage_details)
            expect(formatter).to receive(:puts) # suppress actual output
            format
          end

          it 'says why it is not printing coverage details' do
            expect(formatter).
              to receive(:puts).
              with(/Not showing detailed test coverage because .+/)
            format
          end
        end
      end

      context 'when a test failure has not occurred' do
        before { expect(SimpleCov::Formatter::Terminal.failure_occurred).to eq(false) }

        context 'when test coverage is 100%' do
          context 'when SIMPLECOV_FORCE_DETAILS env var is not set' do
            around do |example|
              ClimateControl.modify(SIMPLECOV_FORCE_DETAILS: nil) do
                example.run
              end
            end

            it 'does not print coverage details' do
              expect(formatter).not_to receive(:print_coverage_details)
              expect(formatter).to receive(:print_coverage_summary)
              format
            end

            context 'when branch coverage is enabled' do
              before { expect(SimpleCov).to receive(:branch_coverage?).and_return(true) }

              it 'includes info about the branch coverage' do
                expect(formatter).
                  to receive(:puts).
                  at_least(:once).
                  with(/\e\[1;32;49m\d+\e\[0m uncovered branches/)

                format
              end
            end

            context 'when branch coverage is not enabled' do
              before { expect(SimpleCov).to receive(:branch_coverage?).and_return(false) }

              it 'does not include info about branch coverage' do
                expect(formatter).
                  not_to receive(:puts).
                  with(/branches/)

                format
              end
            end
          end

          context 'when SIMPLECOV_FORCE_DETAILS env var is set to 1' do
            around do |example|
              ClimateControl.modify(SIMPLECOV_FORCE_DETAILS: '1') do
                example.run
              end
            end

            it 'prints coverage details' do
              expect(formatter).to receive(:print_coverage_details).and_call_original
              expect(formatter).to receive(:puts).at_least(:once) # suppress actual output
              format
            end
          end
        end

        context 'when test coverage is less than 100%' do
          let(:coverage_data) do
            { 'lines' => [nil, nil, 1, 2, 0, 1] }
          end

          before { expect(formatter).to receive(:puts).at_least(:once) } # suppress actual output

          it 'prints coverage details' do
            expect(formatter).to receive(:print_coverage_details).and_call_original
            format
          end

          context 'when the SIMPLECOV_WRITE_TARGET_TO_FILE env var is 1' do
            around do |example|
              ClimateControl.modify(SIMPLECOV_WRITE_TARGET_TO_FILE: '1') do
                example.run
              end
            end

            it 'calls #write_target_info_file' do
              expect(formatter).to receive(:write_target_info_file)
              format
            end
          end
        end
      end
    end
  end

  describe '#targeted_application_file' do
    subject(:targeted_application_file) { formatter.send(:targeted_application_file) }

    context 'when a SIMPLECOV_TARGET_FILE environment variable is present' do
      before { expect(formatter).to receive(:puts).with(/Determined.*from SIMPLECOV_TARGET_FILE/) }

      around do |example|
        ClimateControl.modify(SIMPLECOV_TARGET_FILE: specified_target_file) do
          example.run
        end
      end

      let(:specified_target_file) { 'path/to_a/great_file.rb' }

      it 'returns the specified file' do
        expect(targeted_application_file).to eq(specified_target_file)
      end
    end

    context 'when a SIMPLECOV_TARGET_FILE env var is not present' do
      before do
        expect(SimpleCov::Formatter::Terminal).
          to receive(:executed_spec_files).
          at_least(:once).
          and_return([executed_spec_file])

        allow(SimpleCov::Formatter::Terminal).
          to receive(:spec_file_to_application_file_map).
          and_return(SimpleCov::Formatter::Terminal::SPEC_TO_APP_DEFAULT_MAP)
      end

      context 'when the executed spec file is an admin controller test' do
        let(:executed_spec_file) { 'spec/controllers/admin/csp_reports_controller_spec.rb' }

        it 'returns the correct Active Admin file' do
          expect(targeted_application_file).to eq('app/admin/csp_reports.rb')
        end
      end

      context 'when the executed spec file is a feature test' do
        let(:executed_spec_file) { 'spec/features/home_spec.rb' }

        it 'returns nil' do
          expect(targeted_application_file).to eq(nil)
        end
      end

      context 'when the executed spec file is not matched by any regex' do
        let(:executed_spec_file) { 'spec/dont_know/how_to/map_this_spec.rb' }

        it 'raises an error' do
          expect { targeted_application_file }.
            to raise_error(/Could not map executed spec file .* to application file!/)
        end
      end
    end
  end

  describe '#colored_line' do
    subject(:colored_line) { formatter.send(:colored_line, line, sourcefile) }

    let(:line) do
      instance_double(
        SimpleCov::SourceFile::Line,
        line_number:,
        skipped?: false,
        src: "# frozen_string_literal\n",
        coverage:,
      )
    end
    let(:sourcefile) do
      instance_double(
        SimpleCov::SourceFile,
        lines: [line],
        branches:,
      )
    end
    let(:branches) { [] }
    let(:line_number) { 1 }

    before do
      expect(formatter).to receive(:targeted_application_file).and_return('app/some/file.rb')
      expect(File).to receive(:read).and_return("# frozen_string_literal\n")
    end

    context 'when there is missed_branch_info' do
      let(:branches) do
        [
          instance_double(
            SimpleCov::SourceFile::Branch,
            coverage: 0,
            end_line: 1,
            inline?: true,
            skipped?: false,
            covered?: false,
            start_line: 1,
            type: :else,
          ),
          instance_double(
            SimpleCov::SourceFile::Branch,
            coverage: 0,
            end_line: 1,
            inline?: true,
            skipped?: false,
            covered?: false,
            start_line: 1,
            type: :when,
          ),
        ]
      end

      context 'when the line coverage is 1' do
        let(:coverage) { 1 }

        it 'returns a line with leading yellow boxes and trailing branch info' do
          expect(colored_line).to include('else, when')
        end
      end
    end

    context 'when the line coverage is nil' do
      let(:coverage) { nil }

      it 'returns the source line number in white font with green boundaries' do
        expect(colored_line).
          to start_with("\e[1;39;102m \e[0m\e[0;37;49m  1\e[0m\e[1;39;102m \e[0m")
      end
    end

    context 'when the line coverage is >= 1' do
      let(:coverage) { 1 }

      it 'returns the source line number in green font with green boundaries' do
        expect(colored_line).
          to start_with("\e[1;39;102m \e[0m\e[1;32;49m  1\e[0m\e[1;39;102m \e[0m")
      end
    end

    context 'when the line coverage is 0' do
      let(:coverage) { 0 }

      it 'returns the source line number in white font on a red background' do
        expect(colored_line).
          to start_with("\e[1;37;41m \e[0m\e[1;37;41m  1\e[0m\e[1;37;41m \e[0m")
      end

      context 'when the SIMPLECOV_WRITE_TARGET_TO_FILE env var is 1' do
        around do |example|
          ClimateControl.modify(SIMPLECOV_WRITE_TARGET_TO_FILE: '1') do
            example.run
          end
        end

        it 'prints the source line number preceded by 3 colons' do
          expect(colored_line).to include(":::#{line_number}".rjust(6, ' '))
        end
      end
    end
  end

  describe '#colorized_coverage' do
    subject(:colorized_coverage) { formatter.send(:colorized_coverage, covered_percent) }

    context 'when the covered percent is less than 80' do
      let(:covered_percent) { 79.9912 }

      it 'returns a string with the percentage rounded and in red' do
        expect(colorized_coverage).to eq("\e[0;31m79.99%\e[0m")
      end
    end

    context 'when the covered percent is >= 80 and < 100' do
      let(:covered_percent) { 99.9904 }

      it 'returns a string with the percentage rounded and in yellow' do
        expect(colorized_coverage).to eq("\e[0;33m99.99%\e[0m")
      end
    end

    context 'when the covered percent is 100' do
      let(:covered_percent) { 100.0 }

      it 'returns a string with the percentage rounded and in green' do
        expect(colorized_coverage).to eq("\e[1;32;49m100.0%\e[0m")
      end
    end
  end

  describe '#print_info_for_undetermined_application_target' do
    subject(:print_info_for_undetermined_application_target) do
      formatter.send(:print_info_for_undetermined_application_target)
    end

    it 'prints the expected messages' do
      expect(formatter).to receive(:puts).with(/Not showing test coverage details/)
      expect(formatter).to receive(:puts).with(/Tip: you can specify a file manually/)

      print_info_for_undetermined_application_target
    end
  end

  describe '#print_info_for_nonexistent_application_target' do
    subject(:print_info_for_nonexistent_application_target) do
      formatter.send(:print_info_for_nonexistent_application_target)
    end

    before { expect(formatter).to receive(:targeted_application_file).and_return('app/ruby.rb') }

    it 'prints the expected messages' do
      expect(formatter).to receive(:puts).with(/Looked for .* but it does not exist/)

      print_info_for_nonexistent_application_target
    end
  end

  describe '::gem?' do
    subject(:gem?) { SimpleCov::Formatter::Terminal.send(:gem?) }

    context 'when there is a gemspec file' do
      it 'returns true' do
        expect(gem?).to eq(true)
      end
    end
  end

  describe '::default_map' do
    subject(:default_map) { SimpleCov::Formatter::Terminal.send(:default_map) }

    context 'when within a gem' do
      it 'returns the SPEC_TO_GEM_DEFAULT_MAP' do
        expect(default_map).to eq(SimpleCov::Formatter::Terminal::SPEC_TO_GEM_DEFAULT_MAP)
      end
    end

    context 'when not within a gem' do
      before { expect(SimpleCov::Formatter::Terminal).to receive(:gem?).and_return(false) }

      it 'returns the SPEC_TO_GEM_DEFAULT_MAP' do
        expect(default_map).to eq(SimpleCov::Formatter::Terminal::SPEC_TO_APP_DEFAULT_MAP)
      end
    end
  end

  describe '#executed_spec_file' do
    subject(:executed_spec_file) { formatter.send(:executed_spec_file) }

    context 'when multiple spec files have been executed' do
      before do
        expect(SimpleCov::Formatter::Terminal).
          to receive(:executed_spec_files).
          at_least(:once).
          and_return(['a_spec.rb', 'b_spec.rb'])
      end

      it 'raises an error' do
        expect { executed_spec_file }.to raise_error(/Multiple spec files were executed/)
      end
    end
  end

  describe '#colorized_uncovered_branches' do
    subject(:colorized_uncovered_branches) do
      formatter.send(:colorized_uncovered_branches, num_uncovered_branches)
    end

    context 'when num_uncovered_branches is 0' do
      let(:num_uncovered_branches) { 0 }

      it 'prints 0 in green' do
        expect(colorized_uncovered_branches).to eq("\e[1;32;49m0\e[0m")
      end
    end

    context 'when num_uncovered_branches is between 1 and 3 (inclusive)' do
      let(:num_uncovered_branches) { 2 }

      it 'prints the number of uncovered branches in yellow' do
        expect(colorized_uncovered_branches).to eq("\e[0;33m#{num_uncovered_branches}\e[0m")
      end
    end

    context 'when num_uncovered_branches is greater than 3' do
      let(:num_uncovered_branches) { 4 }

      it 'prints the number of uncovered branches in red' do
        expect(colorized_uncovered_branches).to eq("\e[0;31m#{num_uncovered_branches}\e[0m")
      end
    end
  end

  describe '#missed_branch_info' do
    subject(:missed_branch_info) do
      formatter.send(:missed_branch_info, line, sourcefile)
    end

    let(:line) do
      instance_double(
        SimpleCov::SourceFile::Line,
        line_number: 1,
        skipped?: false,
        src: "puts(rand(10) < 5 ? 'hello world' : 'goodbye world')\n",
        coverage: 1,
      )
    end
    let(:sourcefile) do
      instance_double(
        SimpleCov::SourceFile,
        lines: [line],
        branches: [
          instance_double(
            SimpleCov::SourceFile::Branch,
            coverage: 0,
            end_line: 1,
            inline?: true,
            skipped?: false,
            covered?: false,
            start_line: 1,
            type: :else,
          ),
          instance_double(
            SimpleCov::SourceFile::Branch,
            coverage: 0,
            end_line: 1,
            inline?: true,
            skipped?: false,
            covered?: false,
            start_line: 1,
            type: :when,
          ),
        ],
      )
    end

    context 'when the sourcefile has multiple uncovered branches' do
      it 'returns the uncovered branch descriptors joined by commas' do
        expect(missed_branch_info).to eq('else, when')
      end
    end
  end

  describe '#color' do
    subject(:color) { formatter.send(:color, message, color_code) }

    let(:message) { 'test message' }

    context 'when the color code is :white_on_red' do
      let(:color_code) { :white_on_red }

      it 'returns a string for white font on a red background' do
        expect(color).to eq("\e[1;37;41m#{message}\e[0m")
      end
    end

    context 'when the color code is :purple' do
      let(:color_code) { :purple }

      it 'raises an error' do
        expect { color }.to raise_error("Unknown color format 'purple'.")
      end
    end
  end

  describe '#write_target_info_file' do
    subject(:write_target_info_file) { formatter.send(:write_target_info_file) }

    before { allow(formatter).to receive(:write_target_info_file).and_call_original }

    context 'when a target application file can be determined' do
      before do
        expect(formatter).
          to receive(:targeted_application_file).
          at_least(:once).
          and_return(targeted_application_file)
      end

      let(:targeted_application_file) { 'lib/simple_cov/formatter/terminal.rb' }

      it 'writes the targeted file name to tmp/simple_cov/formatter/terminal/target.txt' do
        expect(File).
          to receive(:write).
          with('tmp/simple_cov/formatter/terminal/target.txt', "#{targeted_application_file}\n")

        write_target_info_file
      end
    end
  end

  describe '#uncovered_branches' do
    subject(:uncovered_branches) { formatter.send(:uncovered_branches, sourcefile) }

    let(:sourcefile) do
      instance_double(
        SimpleCov::SourceFile,
        lines:,
        branches: [branch],
      )
    end
    let(:lines) do
      [
        instance_double(
          SimpleCov::SourceFile::Line,
          skipped?: false,
          src: line_source,
          coverage: line_coverage,
        ),
      ]
    end
    let(:branch) do
      instance_double(
        SimpleCov::SourceFile::Branch,
        coverage: 0,
        end_line: 1,
        inline?: true,
        skipped?: false,
        covered?: false,
        start_line: 1,
        type: branch_type,
      )
    end

    context 'when the line is (partially) covered' do
      let(:line_coverage) { 1 }

      context 'when there is an uncovered `else` branch' do
        let(:branch_type) { :else }

        context 'when there is a comment ignoring `else` branch coverage' do
          let(:line_source) { "if rand(10) < 5 ? 'small' : 'big' \# :nocov-else:" }

          it 'does not include the branch' do
            expect(uncovered_branches).not_to include(branch)
          end
        end

        context 'when there is a comment ignoring `when` branch coverage' do
          let(:line_source) { "if rand(10) < 5 ? 'small' : 'big' \# :nocov-when:" }

          it 'includes the branch' do
            expect(uncovered_branches).to include(branch)
          end
        end
      end
    end
  end
end
