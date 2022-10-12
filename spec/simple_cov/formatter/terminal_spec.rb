# frozen_string_literal: true

RSpec.describe SimpleCov::Formatter::Terminal do
  subject(:formatter) { SimpleCov::Formatter::Terminal.allocate }

  describe '#targeted_application_file' do
    subject(:targeted_application_file) { formatter.send(:targeted_application_file) }

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

    let(:line) { Struct.new('Line', :line_number, :coverage).new(1, coverage) }

    before do
      expect(formatter).to receive(:targeted_application_file).and_return('app/some/file.rb')
      expect(File).to receive(:read).and_return("# frozen_string_literal\n")
    end

    context 'when the line coverage is nil' do
      let(:coverage) { nil }

      it 'returns the source line with a gray box at the beginning' do
        expect(colored_line).to start_with("\e[1;30m░░ \e[0m\e[38;5;239m")
      end
    end

    context 'when the line coverage is >= 1' do
      let(:coverage) { 1 }

      it 'returns the source line with a green box at the beginning' do
        expect(colored_line).to start_with("\e[1;32m██ \e[0m\e[38;5;239m")
      end
    end

    context 'when the line coverage is 0' do
      let(:coverage) { 0 }

      it 'returns the source line with a red box at the beginning' do
        expect(colored_line).to start_with("\e[1;31m██ \e[0m\e[38;5;239m")
      end
    end
  end
end
