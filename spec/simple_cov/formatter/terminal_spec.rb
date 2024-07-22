# frozen_string_literal: true

RSpec.describe SimpleCov::Formatter::Terminal do
  subject(:formatter) { SimpleCov::Formatter::Terminal.new }

  around do |example|
    ClimateControl.modify(SIMPLECOV_WRITE_TARGET_TO_FILE: nil) do
      example.run
    end
  end

  before do
    # Don't actually write to file.
    allow(File).to receive(:write)
  end

  describe '::_setup_rspec' do
    subject(:_setup_rspec) do
      SimpleCov::Formatter::Terminal::RSpecIntegration.send(:_setup_rspec)
    end

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

          SimpleCov::Formatter::Terminal::RSpecIntegration.failure_occurred = false
        end

        block.call(double)
      end

      _setup_rspec
    end
  end

  describe '#format' do
    # rubocop:disable RSpec/EmptyLineAfterSubject, RSpec/MultipleSubjects
    subject(:format) { formatter.format(result) }
    subject(:result_printer) { formatter.send(:result_printer) }
    # rubocop:enable RSpec/EmptyLineAfterSubject, RSpec/MultipleSubjects

    let(:result) { instance_double(SimpleCov::Result) }

    context 'when no specs have been successfully executed' do
      before do
        expect(formatter).
          to receive(:executed_spec_files).
          and_return(nil)
      end

      it 'prints a message about no specs having been executed' do
        expect(result_printer).to receive(:puts).with(/no specs were executed successfully/)
        format
      end
    end

    context 'when one spec file has been executed' do
      before do
        expect(formatter.send(:file_determiner)).
          to receive(:executed_spec_files).
          at_least(:once).
          and_return(['cool_spec.rb'])
      end

      context 'when a targeted application file cannot possibly be determined' do
        before do
          expect(formatter.send(:file_determiner)).
            to receive(:unmappable_spec_file?).
            and_return(true)
        end

        it 'prints info about an undeterminable application target' do
          expect(result_printer).to receive(:print_info_for_undeterminable_application_target)
          format
        end
      end

      context 'when a targeted application file was not determined (but maybe could be)' do
        before do
          expect(formatter.send(:file_determiner)).
            to receive(:unmappable_spec_file?).
            and_return(false)

          expect(formatter.send(:file_determiner)).
            to receive(:targeted_application_file).
            and_return(nil)
        end

        it 'prints info about an undetermined application target' do
          expect(result_printer).to receive(:print_info_for_undetermined_application_target)
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
          expect(formatter.send(:file_determiner)).
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
            expect(result_printer).to receive(:puts).with(/No code coverage info was found/)
            format
          end
        end

        context 'when a test failure failure occurred' do
          around do |spec|
            SimpleCov::Formatter::Terminal::RSpecIntegration.failure_occurred = true
            spec.run
            SimpleCov::Formatter::Terminal::RSpecIntegration.failure_occurred = false
          end

          context 'when SIMPLECOV_FORCE_DETAILS env var is not set' do
            around do |example|
              ClimateControl.modify(SIMPLECOV_FORCE_DETAILS: nil) do
                example.run
              end
            end

            it 'does not print coverage details' do
              expect(result_printer).not_to receive(:print_coverage_details)
              expect(result_printer).to receive(:puts) # suppress actual output
              format
            end

            it 'says why it is not printing coverage details' do
              expect(result_printer).
                to receive(:puts).
                with(/Not showing detailed coverage because .+/)
              format
            end
          end
        end

        context 'when a test failure has not occurred' do
          before do
            expect(SimpleCov::Formatter::Terminal::RSpecIntegration.failure_occurred).to eq(false)
          end

          context 'when test coverage is 100%' do
            context 'when SIMPLECOV_FORCE_DETAILS env var is not set' do
              around do |example|
                ClimateControl.modify(SIMPLECOV_FORCE_DETAILS: nil) do
                  example.run
                end
              end

              it 'does not print coverage details' do
                expect(result_printer).not_to receive(:print_coverage_details)
                expect(result_printer).to receive(:print_coverage_summary)
                format
              end

              context 'when branch coverage is enabled' do
                before { expect(SimpleCov).to receive(:branch_coverage?).and_return(true) }

                it 'includes info about the branch coverage' do
                  expect(result_printer).
                    to receive(:puts).
                    at_least(:once).
                    with(/Uncovered branches: \e\[1;32;49m0\e\[0m/)

                  format
                end
              end

              context 'when branch coverage is not enabled' do
                before { expect(SimpleCov).to receive(:branch_coverage?).and_return(false) }

                it 'does not include info about branch coverage' do
                  expect(result_printer).
                    not_to receive(:puts).
                    with(/branches/)

                  expect(result_printer).
                    to receive(:puts).
                    with(/Line coverage:/)

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
                expect(result_printer).to receive(:print_coverage_details)
                format
              end
            end
          end

          context 'when test coverage is less than 100%' do
            let(:coverage_data) do
              { 'lines' => [nil, nil, 1, 2, 0, 1] }
            end

            it 'prints coverage details' do
              expect(result_printer).to receive(:print_coverage_details)
              format
            end

            context 'when the SIMPLECOV_WRITE_TARGET_TO_FILE env var is 1' do
              around do |example|
                ClimateControl.modify(SIMPLECOV_WRITE_TARGET_TO_FILE: '1') do
                  example.run
                end
              end

              it 'calls #write_target_info_file' do
                expect(result_printer.send(:target_file_writer)).to receive(:write_target_info_file)
                expect(result_printer).to receive(:puts).at_least(:once) # suppress output
                format
              end
            end
          end
        end
      end
    end
  end

  describe '#executed_spec_file' do
    subject(:executed_spec_file) { formatter.send(:executed_spec_file) }

    context 'when multiple spec files have been executed' do
      before do
        expect(SimpleCov::Formatter::Terminal::RSpecIntegration).
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
