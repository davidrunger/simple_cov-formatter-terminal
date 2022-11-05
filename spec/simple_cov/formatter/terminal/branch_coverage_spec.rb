# frozen_string_literal: true

RSpec.describe(SimpleCov::Formatter::Terminal::BranchCoverage) do
  subject(:printer) { Printer.new }

  before do
    stub_const('Printer', Class.new)

    Printer.class_eval do
      include SimpleCov::Formatter::Terminal::BranchCoverage
    end
  end

  describe '#missed_branch_info' do
    subject(:missed_branch_info) do
      printer.send(:missed_branch_info, line, sourcefile)
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

  describe '#uncovered_branches' do
    subject(:uncovered_branches) { printer.send(:uncovered_branches, sourcefile) }

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
