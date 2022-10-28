# frozen_string_literal: true

RSpec.describe(PrintUtils) do
  subject(:printer) { Printer.new }

  before do
    stub_const('Printer', Class.new)

    Printer.class_eval do
      include PrintUtils
    end
  end

  describe '#colored_line' do
    subject(:colored_line) { printer.colored_line(line, sourcefile) }

    let(:line_source_code) { '# frozen_string_literal' }
    let(:line) do
      instance_double(
        SimpleCov::SourceFile::Line,
        line_number: 1,
        skipped?: skipped?,
        src: "#{line_source_code}\n",
        coverage: nil,
      )
    end
    let(:sourcefile) do
      instance_double(
        SimpleCov::SourceFile,
        lines: [line],
      )
    end

    before do
      expect(printer).to receive(:targeted_application_file).and_return('app/file.rb')
      expect(File).to receive(:read).with('app/file.rb').and_return("# frozen_string_literal\n")
      expect(printer).to receive(:write_target_info_file?).and_return(false)
    end

    context 'when the line is skipped' do
      let(:skipped?) { true }

      it 'returns the syntax-highlighted source code with line number in white padded in green' do
        expect(colored_line).to eq(
          "\e[1;39;102m \e[0m\e[0;37;49m  1\e[0m\e[1;39;102m \e[0m \e[38;5;239m" \
          "#{line_source_code}\e[39m\e[38;5;252m\e[39m",
        )
      end
    end
  end
end
