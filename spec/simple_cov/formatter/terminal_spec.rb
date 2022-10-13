# frozen_string_literal: true

RSpec.describe SimpleCov::Formatter::Terminal do
  subject(:formatter) { SimpleCov::Formatter::Terminal.allocate }

  describe '::_setup_rspec' do
    it 'calls the expected methods' do
      expect(RSpec).to receive(:configure) do |&block|
        double = instance_double(RSpec::Core::Configuration)

        expect(double).to receive(:before).with(:suite).and_yield

        expect(double).to receive(:after).with(:suite) do |&after_block|
          expect(RSpec.world).
            to receive(:filtered_examples).
            and_return({
              'dummy' => Struct.new(:exception).new(StandardError.new),
            })

          after_block.call

          SimpleCov::Formatter::Terminal.failure_occurred = false
        end

        block.call(double)
      end

      SimpleCov::Formatter::Terminal._setup_rspec
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
          to receive(:executed_spec_file).
          at_least(:once).
          and_return('spec/controllers/admin/csp_reports_controller_spec.rb')

        expect(SimpleCov::Formatter::Terminal).
          to receive(:spec_file_to_application_file_map).
          and_return(SimpleCov::Formatter::Terminal::DEFAULT_SPEC_TO_APP_MAP)
      end

      it 'returns the correct Active Admin file' do
        expect(targeted_application_file).to eq('app/admin/csp_reports.rb')
      end
    end
  end

  describe '#colored_line' do
    subject(:colored_line) { formatter.send(:colored_line, line) }

    let(:line) { Struct.new(:line_number, :coverage, :skipped?).new(1, coverage, false) }

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
end
