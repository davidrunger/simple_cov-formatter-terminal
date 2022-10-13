# frozen_string_literal: true

RSpec.describe SimpleCov::Formatter::Terminal do
  subject(:formatter) { SimpleCov::Formatter::Terminal.allocate }

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

    let(:result) { SimpleCov::Result.allocate }

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

        it 'does not print coverage details' do
          expect(formatter).not_to receive(:print_coverage_details)
          expect(formatter).to receive(:puts) # suppress actual output
          format
        end

        it 'says why it is not printing coverage details' do
          expect(formatter).to receive(:puts).with(/Not showing detailed test coverage because .+/)
          format
        end
      end

      context 'when a test failure has not occurred' do
        before { expect(SimpleCov::Formatter::Terminal.failure_occurred).to eq(false) }

        context 'when test coverage is 100%' do
          it 'does not print coverage details' do
            expect(formatter).not_to receive(:print_coverage_details).and_call_original
            expect(formatter).to receive(:puts) # suppress actual output
            format
          end
        end

        context 'when test coverage is less than 100%' do
          let(:coverage_data) do
            { 'lines' => [nil, nil, 1, 2, 0, 1] }
          end

          it 'prints coverage details' do
            expect(formatter).to receive(:print_coverage_details).and_call_original
            expect(formatter).to receive(:puts).at_least(:once) # suppress actual output
            format
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

    context 'when the executed spec file is an admin controller test' do
      before do
        expect(SimpleCov::Formatter::Terminal).
          to receive(:executed_spec_files).
          at_least(:once).
          and_return(['spec/controllers/admin/csp_reports_controller_spec.rb'])

        expect(SimpleCov::Formatter::Terminal).
          to receive(:spec_file_to_application_file_map).
          and_return(SimpleCov::Formatter::Terminal::SPEC_TO_APP_DEFAULT_MAP)
      end

      it 'returns the correct Active Admin file' do
        expect(targeted_application_file).to eq('app/admin/csp_reports.rb')
      end
    end
  end

  describe '#colored_line' do
    subject(:colored_line) { formatter.send(:colored_line, line) }

    let(:line) do
      instance_double(
        SimpleCov::SourceFile::Line,
        line_number: 1,
        skipped?: false,
        coverage:,
      )
    end

    before do
      expect(formatter).to receive(:targeted_application_file).and_return('app/some/file.rb')
      expect(File).to receive(:read).and_return("# frozen_string_literal\n")
    end

    context 'when the line coverage is nil' do
      let(:coverage) { nil }

      it 'returns the source line with a gray box at the beginning' do
        expect(colored_line).to start_with("\e[0;30m░░ \e[0m")
      end
    end

    context 'when the line coverage is >= 1' do
      let(:coverage) { 1 }

      it 'returns the source line with a green box at the beginning' do
        expect(colored_line).to start_with("\e[0;32m██ \e[0m")
      end
    end

    context 'when the line coverage is 0' do
      let(:coverage) { 0 }

      it 'returns the source line with a red box at the beginning' do
        expect(colored_line).to start_with("\e[0;31m██ \e[0m")
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
        expect(colorized_coverage).to eq("\e[0;32m100.0%\e[0m")
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
end
