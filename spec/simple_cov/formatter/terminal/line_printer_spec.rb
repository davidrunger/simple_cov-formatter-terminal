# frozen_string_literal: true

RSpec.describe(SimpleCov::Formatter::Terminal::LinePrinter) do
  subject(:printer) { SimpleCov::Formatter::Terminal::LinePrinter.new(targeted_application_file) }

  let(:targeted_application_file) { 'app/file.rb' }

  describe '#colored_line' do
    subject(:colored_line) do
      printer.colored_line(line, sourcefile)
    end

    let(:line_source_code) { '# frozen_string_literal' }
    let(:line) do
      instance_double(
        SimpleCov::SourceFile::Line,
        line_number:,
        skipped?: skipped?,
        src: line_source_code,
        coverage:,
      )
    end
    let(:coverage) { nil }
    let(:sourcefile) do
      instance_double(
        SimpleCov::SourceFile,
        lines: [line],
        branches:,
      )
    end
    let(:skipped?) { false }
    let(:branches) { [] }
    let(:line_number) { 1 }
    let(:terminal_hyperlink_target_pattern) { nil }

    before do
      expect(File).
        to receive(:read).
        with('app/file.rb').
        and_return("# frozen_string_literal\n")

      allow(SimpleCov::Formatter::Terminal.config).
        to receive(:terminal_hyperlink_target_pattern).
        and_return(terminal_hyperlink_target_pattern)
    end

    context 'when the line is skipped' do
      let(:skipped?) { true }

      it 'returns the syntax-highlighted source code with line number in white padded in green' do
        expect(colored_line).to eq(
          "\e[1;39;102m \e[0m\e[0;37;49m  1\e[0m\e[1;39;102m \e[0m \e[38;5;240m" \
          "#{line_source_code}\e[39m\e[38;5;188m\e[39m",
        )
      end
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

      context 'when terminal_hyperlink_target_pattern is truthy' do
        let(:terminal_hyperlink_target_pattern) { 'vscode:%f:%l' }

        it 'prints a link (using the pattern) to the source line' do
          expect(colored_line).to include(
            "\e]8;;vscode:#{ENV['PWD']}/app/file.rb:1\e\\  1\e]8;;\e\\",
          )
        end
      end
    end
  end

  describe '#color' do
    subject(:color) { printer.send(:color, message, color_code) }

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
end
