# frozen_string_literal: true

require_relative 'branch_coverage'
require_relative 'color_printing'
require_relative 'line_printer'
require_relative 'target_file_writer'

class SimpleCov::Formatter::Terminal::ResultPrinter
  extend Forwardable
  prepend MemoWise
  include SimpleCov::Formatter::Terminal::BranchCoverage
  include SimpleCov::Formatter::Terminal::ColorPrinting

  def_delegators(:@file_determiner, :executed_spec_file, :targeted_application_file)

  def initialize(file_determiner)
    @file_determiner = file_determiner
  end

  def print_coverage_info(result)
    sourcefile = result.files.find { _1.filename.end_with?(targeted_application_file) }
    force_coverage = ENV.fetch('SIMPLECOV_FORCE_DETAILS', nil) == '1'

    if sourcefile.nil?
      print_no_coverage_info_found
    elsif failure_occurred? && !force_coverage
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
    if SimpleCov::Formatter::Terminal.config.write_target_info_file?
      target_file_writer.write_target_info_file
    end

    puts("---- Coverage for #{targeted_application_file} ".ljust(80, '-').rstrip)
    sourcefile.lines.each do |line|
      puts(line_printer.colored_line(line, sourcefile))
    end
    puts(<<~LOG.squish)
      ----
      Line coverage: #{colorized_coverage(sourcefile.covered_percent)}
      |
      Uncovered branches: #{colorized_uncovered_branches(uncovered_branches(sourcefile).size)}
      ----
    LOG
  end

  def print_no_coverage_info_found
    puts(<<~LOG.squish)
      No code coverage info was found for "#{targeted_application_file}". Try stopping and
      disabling `spring`, if you are using it, and then rerun the spec.
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

  private

  def failure_occurred?
    SimpleCov::Formatter::Terminal::RSpecIntegration.failure_occurred?
  end

  memo_wise \
  def target_file_writer
    SimpleCov::Formatter::Terminal::TargetFileWriter.new(targeted_application_file)
  end

  def colorized_coverage(covered_percent)
    case
    when covered_percent >= 100 then color("#{covered_percent.round(2)}%", :green)
    when covered_percent >= 80 then color("#{covered_percent.round(2)}%", :yellow)
    else color("#{covered_percent.round(2)}%", :red)
    end
  end

  def colorized_uncovered_branches(num_uncovered_branches)
    case num_uncovered_branches
    when 0 then color(num_uncovered_branches.to_s, :green)
    when (1..3) then color(num_uncovered_branches.to_s, :yellow)
    else color(num_uncovered_branches.to_s, :red)
    end
  end

  memo_wise \
  def line_printer
    SimpleCov::Formatter::Terminal::LinePrinter.new(targeted_application_file)
  end
end
