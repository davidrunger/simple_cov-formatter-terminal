# frozen_string_literal: true

require 'memoist'

module BranchCoverage
  extend Memoist

  memoize \
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
      select { _1.start_line == line.line_number }.
      map { _1.type.to_s }.
      join(', ')
  end
end
