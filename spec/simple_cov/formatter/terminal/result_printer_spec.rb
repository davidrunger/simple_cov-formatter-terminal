# frozen_string_literal: true

RSpec.describe(SimpleCov::Formatter::Terminal::ResultPrinter) do
  subject(:result_printer) do
    SimpleCov::Formatter::Terminal::ResultPrinter.new(file_determiner)
  end

  let(:file_determiner) { SimpleCov::Formatter::Terminal::FileDeterminer.new }
  let(:sourcefile) do
    instance_double(
      SimpleCov::SourceFile,
      covered_percent: 80.5,
      filename: targeted_application_file,
      lines: [
        instance_double(
          SimpleCov::SourceFile::Line,
          line_number: 1,
          skipped?: false,
          src: "puts(rand(10) < 5 ? 'hello world' : 'goodbye world')\n",
          coverage: 1,
        ),
      ],
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
  let(:targeted_application_file) { 'a_nifty_file.rb' }

  describe '#print_coverage_details' do
    subject(:print_coverage_details) { result_printer.print_coverage_details(sourcefile) }

    before do
      expect(SimpleCov::Formatter::Terminal.config).
        to receive(:write_target_info_file?).
        at_least(:once).
        and_return(false)

      expect(result_printer).
        to receive(:targeted_application_file).
        at_least(:once).
        and_return(targeted_application_file)

      expect(File).
        to receive(:read).
        with(targeted_application_file).
        and_return("# frozen_string_literal\n")
    end

    it 'prints stuff' do
      expect(result_printer).to receive(:puts).at_least(:once)
      print_coverage_details
    end
  end

  describe '#print_info_for_nonexistent_application_target' do
    subject(:print_info_for_nonexistent_application_target) do
      result_printer.print_info_for_nonexistent_application_target
    end

    before do
      expect(file_determiner).to receive(:targeted_application_file).and_return('nifty_file.rb')
    end

    it 'prints the expected messages' do
      expect(result_printer).to receive(:puts).with(/Looked for .* but it does not exist/)

      print_info_for_nonexistent_application_target
    end
  end

  describe '#print_info_for_undeterminable_application_target' do
    subject(:print_info_for_undeterminable_application_target) do
      result_printer.send(:print_info_for_undeterminable_application_target)
    end

    before do
      expect(file_determiner).to receive(:executed_spec_file).and_return('nifty_spec.rb')
    end

    it 'prints the expected messages' do
      expect(result_printer).to receive(:puts).with(/Not showing test coverage details/)
      expect(result_printer).to receive(:puts).with(/Tip: you can specify a file manually/)

      print_info_for_undeterminable_application_target
    end
  end

  describe '#print_info_for_undetermined_application_target' do
    subject(:print_info_for_undetermined_application_target) do
      result_printer.send(:print_info_for_undetermined_application_target)
    end

    before do
      expect(file_determiner).to receive(:executed_spec_file).and_return('nifty_spec.rb')
    end

    it 'prints the expected messages' do
      expect(result_printer).to receive(:puts).
        with(/\ANot showing test coverage details because we could not map/)
      expect(result_printer).to receive(:puts).
        with(/\ATip: You can provide a mapping/)

      print_info_for_undetermined_application_target
    end
  end

  describe '#colorized_coverage' do
    subject(:colorized_coverage) { result_printer.send(:colorized_coverage, covered_percent) }

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

  describe '#colorized_uncovered_branches' do
    subject(:colorized_uncovered_branches) do
      result_printer.send(:colorized_uncovered_branches, num_uncovered_branches)
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

  describe '#line_numbers_to_print' do
    context 'when line_numbers_to_print config is :all' do
      around do |example|
        original_lines_to_print = SimpleCov::Formatter::Terminal.config.lines_to_print
        SimpleCov::Formatter::Terminal.config.lines_to_print = :all

        example.run

        SimpleCov::Formatter::Terminal.config.lines_to_print = original_lines_to_print
      end

      before do
        result_printer.instance_variable_set(:@sourcefile, sourcefile)
      end

      it 'returns a Set that includes every line number in the file' do
        expect(result_printer.send(:line_numbers_to_print)).to eq(Set[1])
      end
    end
  end
end
