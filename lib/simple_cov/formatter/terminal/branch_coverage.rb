# frozen_string_literal: true

require 'memo_wise'

module SimpleCov::Formatter::Terminal::BranchCoverage
  prepend MemoWise

  private

  memo_wise \
  def uncovered_branches(sourcefile)
    sourcefile.branches.
      reject(&:covered?).
      reject do |branch|
        line = sourcefile.lines[branch.start_line - 1]
        source_code = line.src
        line.coverage == 0 || source_code.match?(/# :nocov-(#{branch.type}):/)
      end
  end

  def missed_branch_info(line, sourcefile)
    uncovered_branches(sourcefile).
      select { it.start_line == line.line_number }.
      map { it.type.to_s }.
      join(', ').
      presence
  end

  memo_wise \
  def line_numbers_with_missing_branches(sourcefile)
    uncovered_branches(sourcefile).
      map(&:start_line).
      uniq.
      sort
  end
end
