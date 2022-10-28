# frozen_string_literal: true

require_relative './branch_coverage'
require_relative './print_utils'

module PrintCommands
  include BranchCoverage
  include PrintUtils

  def print_coverage_info(result)
    sourcefile = result.files.find { _1.filename.end_with?(targeted_application_file) }
    force_coverage = ENV.fetch('SIMPLECOV_FORCE_DETAILS', nil) == '1'

    if sourcefile.nil?
      puts(<<~LOG.squish)
        No code coverage info was found for "#{targeted_application_file}". Try stopping and
        disabling `spring`, if you are using it, and then rerun the spec.
      LOG
    elsif self.class.failure_occurred && !force_coverage
      print_coverage_summary(sourcefile, 'Not showing detailed coverage because an example failed.')
    elsif sourcefile.covered_percent < 100 || uncovered_branches(sourcefile).any? || force_coverage
      print_coverage_details(sourcefile)
    else
      print_coverage_summary(sourcefile)
    end
  end

  def print_coverage_summary(sourcefile, log_addendum = nil)
    summary = +"-- Coverage for #{targeted_application_file} --\n"
    summary << "Line coverage: #{colorized_coverage(sourcefile.covered_percent)}"
    if SimpleCov.branch_coverage?
      summary << ' '
      summary << <<~LOG
        | Uncovered branches: #{colorized_uncovered_branches(uncovered_branches(sourcefile).size)}
      LOG
    else
      summary << "\n"
    end
    summary << log_addendum if log_addendum
    puts(summary)
  end

  def print_coverage_details(sourcefile)
    puts("---- Coverage for #{targeted_application_file} ".ljust(80, '-').rstrip)
    sourcefile.lines.each do |line|
      puts(colored_line(line, sourcefile))
    end
    puts(<<~LOG.squish)
      ----
      Line coverage: #{colorized_coverage(sourcefile.covered_percent)}
      |
      Uncovered branches: #{colorized_uncovered_branches(uncovered_branches(sourcefile).size)}
      ----
    LOG
  end

  def print_info_for_no_executed_specs
    puts('Not showing test coverage details because no specs were executed successfully.')
  end

  def print_info_for_undetermined_application_target
    puts(<<~LOG.squish)
      Not showing test coverage details because "#{executed_spec_file}" cannot
      be mapped to a single application file.
    LOG
    puts(<<~LOG.squish)
      Tip: you can specify a file manually via a SIMPLECOV_TARGET_FILE environment variable.
    LOG
  end

  def print_info_for_nonexistent_application_target
    puts(<<~LOG.squish)
      Cannot show code coverage. Looked for application file "#{targeted_application_file}",
      but it does not exist.
    LOG
  end
end
