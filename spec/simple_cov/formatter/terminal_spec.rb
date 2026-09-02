# frozen_string_literal: true

RSpec.describe SimpleCov::Formatter::Terminal do
  subject(:formatter) { SimpleCov::Formatter::Terminal.new }

  before do
    # Don't actually write to file.
    allow(File).to receive(:write)
  end

  describe '::setup_rspec' do
    it 'does not set up RSpec again' do
      allow(RSpec).to receive(:configure)

      SimpleCov::Formatter::Terminal::RSpecIntegration.setup_rspec

      expect(RSpec).not_to have_received(:configure)
    end
  end

  describe '::_setup_rspec' do
    subject(:_setup_rspec) do
      SimpleCov::Formatter::Terminal::RSpecIntegration.send(:_setup_rspec)
    end

    it 'calls the expected methods' do
      allow(RSpec).to receive(:configure) do |&block|
        double = instance_double(RSpec::Core::Configuration)

        allow(double).to receive(:before).with(:suite).and_yield

        allow(double).to receive(:after).with(:suite) do |&after_block|
          rspec_example_double =
            instance_double(
              RSpec::Core::Example,
              exception: StandardError.new,
              file_path: './spec/models/user.rb',
            )

          allow(RSpec.world).
            to receive(:filtered_examples).
            and_return({ 'irrelevant_key' => rspec_example_double })

          after_block.call

          expect(RSpec.world).to have_received(:filtered_examples)

          SimpleCov::Formatter::Terminal::RSpecIntegration.failure_occurred = false
        end

        block.call(double)

        expect(double).to have_received(:before).with(:suite)
        expect(double).to have_received(:after).with(:suite)
      end

      _setup_rspec

      expect(RSpec).to have_received(:configure)
    end
  end

  describe '#format' do
    # rubocop:disable RSpec/EmptyLineAfterSubject, RSpec/MultipleSubjects
    subject(:format) { formatter.format(result) }
    subject(:result_printer) { formatter.send(:result_printer) }
    # rubocop:enable RSpec/EmptyLineAfterSubject, RSpec/MultipleSubjects

    let(:result) { instance_double(SimpleCov::Result) }

    context 'when DISABLE_SIMPLECOV_TERMINAL env var is present' do
      around do |spec|
        ClimateControl.modify(DISABLE_SIMPLECOV_TERMINAL: '1') do
          spec.run
        end
      end

      it 'does not print anything' do
        allow(result_printer).to receive(:puts)

        format

        expect(result_printer).not_to have_received(:puts)
      end
    end

    context 'when DISABLE_SIMPLECOV_TERMINAL env var is not present' do
      before { expect(ENV).not_to have_key('DISABLE_SIMPLECOV_TERMINAL') }

      context 'when no specs have been successfully executed' do
        before do
          allow(formatter).
            to receive(:executed_spec_files).
            and_return(nil)
        end

        after do
          expect(formatter).to have_received(:executed_spec_files).once
        end

        it 'prints a message about no specs having been executed' do
          allow(result_printer).to receive(:puts)

          format

          expect(result_printer).to have_received(:puts).with(/no specs were executed successfully/)
        end
      end

      context 'when one spec file has been executed' do
        before do
          allow(formatter.send(:file_determiner)).
            to receive(:executed_spec_files).
            and_return(['cool_spec.rb'])
        end

        after do
          expect(formatter.send(:file_determiner)).
            to have_received(:executed_spec_files).
            at_least(:once)
        end

        context 'when a targeted application file cannot possibly be determined from the spec file alone' do
          before do
            allow(formatter.send(:file_determiner)).
              to receive(:unmappable_spec_file?).
              and_return(true)
          end

          after do
            expect(formatter.send(:file_determiner)).
              to have_received(:unmappable_spec_file?).
              at_least(:once)
          end

          context 'when a SIMPLECOV_TARGET_FILE env var has been provided' do
            around do |spec|
              ClimateControl.modify(
                SIMPLECOV_TARGET_FILE: 'lib/simple_cov/formatter/terminal.rb',
              ) do
                spec.run
              end
            end

            it 'prints coverage info' do
              allow(result_printer).to receive(:print_coverage_info)

              format

              expect(result_printer).to have_received(:print_coverage_info)
            end
          end

          context 'when a SIMPLECOV_TARGET_FILE env var has not been provided' do
            around do |spec|
              ClimateControl.modify(SIMPLECOV_TARGET_FILE: nil) do
                spec.run
              end
            end

            it 'prints info about an undeterminable application target' do
              allow(result_printer).to receive(:print_info_for_undeterminable_application_target)

              format

              expect(result_printer).to have_received(
                :print_info_for_undeterminable_application_target,
              )
            end
          end
        end

        context 'when a targeted application file was not determined (but maybe could be)' do
          before do
            allow(formatter.send(:file_determiner)).
              to receive_messages(unmappable_spec_file?: false, targeted_application_file: nil)
          end

          after do
            expect(formatter.send(:file_determiner)).
              to have_received(:unmappable_spec_file?).
              once
            expect(formatter.send(:file_determiner)).
              to have_received(:targeted_application_file).
              once
          end

          it 'prints info about an undetermined application target' do
            allow(result_printer).to receive(:print_info_for_undetermined_application_target)

            format

            expect(result_printer).to have_received(:print_info_for_undetermined_application_target)
          end
        end

        context 'when the "targeted application file" does not actually exist' do
          before do
            allow(formatter).
              to receive(:targeted_application_file).
              and_return('not/there.rb')
          end

          after do
            expect(formatter).
              to have_received(:targeted_application_file).
              at_least(:once)
          end

          it 'prints the appropriate info' do
            allow(formatter).to receive(:print_info_for_nonexistent_application_target)

            format

            expect(formatter).to have_received(:print_info_for_nonexistent_application_target)
          end
        end

        context 'when the targeted application file exists' do
          before do
            allow(formatter.send(:file_determiner)).
              to receive(:targeted_application_file).
              and_return(targeted_application_file)

            allow(result).to receive(:files).and_return(files)
          end

          after do
            expect(formatter.send(:file_determiner)).
              to have_received(:targeted_application_file).
              at_least(:once)
            expect(result).to have_received(:files).once
          end

          let(:targeted_application_file) { 'lib/simple_cov/formatter/terminal.rb' }
          let(:files) { [SimpleCov::SourceFile.new(targeted_application_file, coverage_data)] }
          let(:coverage_data) do
            { 'lines' => [] }
          end

          context 'when there is no coverage info about the targeted file' do
            let(:files) { [SimpleCov::SourceFile.new('app/not/the/target/file.rb', coverage_data)] }

            it 'prints that no coverage info was found' do
              allow(result_printer).to receive(:puts)

              format

              expect(result_printer).to have_received(:puts).with(/No code coverage info was found/)
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
                allow(result_printer).to receive(:print_coverage_details)
                allow(result_printer).to receive(:puts) # suppress actual output

                format

                expect(result_printer).not_to have_received(:print_coverage_details)
                expect(result_printer).to have_received(:puts)
              end

              it 'says why it is not printing coverage details' do
                allow(result_printer).
                  to receive(:puts).
                  with(/Not showing detailed coverage because .+/)

                format

                expect(result_printer).to have_received(:puts).
                  with(/Not showing detailed coverage because .+/)
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
                  allow(result_printer).to receive(:print_coverage_details)
                  allow(result_printer).to receive(:print_coverage_summary)

                  format

                  expect(result_printer).not_to have_received(:print_coverage_details)
                  expect(result_printer).to have_received(:print_coverage_summary)
                end

                context 'when branch coverage is enabled' do
                  before { allow(SimpleCov).to receive(:branch_coverage?).and_return(true) }

                  after do
                    expect(SimpleCov).to have_received(:branch_coverage?).once
                  end

                  it 'includes info about the branch coverage' do
                    allow(result_printer).
                      to receive(:puts).
                      with(/Uncovered branches: \e\[1;32;49m0\e\[0m/)

                    format

                    expect(result_printer).to have_received(:puts).
                      with(/Uncovered branches: \e\[1;32;49m0\e\[0m/)
                  end
                end

                context 'when branch coverage is not enabled' do
                  before { allow(SimpleCov).to receive(:branch_coverage?).and_return(false) }

                  after do
                    expect(SimpleCov).to have_received(:branch_coverage?).once
                  end

                  it 'does not include info about branch coverage' do
                    allow(result_printer).to receive(:puts)

                    format

                    expect(result_printer).
                      not_to have_received(:puts).
                      with(/branches/)

                    expect(result_printer).
                      to have_received(:puts).
                      with(/Line coverage:/)
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
                  allow(result_printer).to receive(:print_coverage_details)

                  format

                  expect(result_printer).to have_received(:print_coverage_details)
                end
              end
            end

            context 'when test coverage is less than 100%' do
              let(:coverage_data) do
                { 'lines' => [nil, nil, 1, 2, 0, 1] }
              end

              it 'prints coverage details' do
                allow(result_printer).to receive(:print_coverage_details)

                format

                expect(result_printer).to have_received(:print_coverage_details)
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
        allow(SimpleCov::Formatter::Terminal::RSpecIntegration).
          to receive(:executed_spec_files).
          and_return(['a_spec.rb', 'b_spec.rb'])
      end

      after do
        expect(SimpleCov::Formatter::Terminal::RSpecIntegration).
          to have_received(:executed_spec_files).
          at_least(:once)
      end

      it 'raises an error' do
        expect { executed_spec_file }.to raise_error(/Multiple spec files were executed/)
      end
    end
  end
end
