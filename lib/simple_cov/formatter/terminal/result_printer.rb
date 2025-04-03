# frozen_string_literal: true

require_relative 'branch_coverage'
require_relative 'color_printing'
require_relative 'line_printer'

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
    sourcefile = result.files.find { it.filename.end_with?(targeted_application_file) }
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
    summary = "-- Coverage for #{targeted_application_file} --\n"
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
    @sourcefile = sourcefile

    puts("---- Coverage for #{targeted_application_file} ".ljust(80, '-').rstrip)

    skipped_lines = []
    sourcefile.lines.each do |line|
      if print_line?(line.line_number)
        if skipped_lines.any?
          print_skipped_lines(skipped_lines)
        end

        puts(line_printer.colored_line(line, sourcefile))
        skipped_lines = []
      else
        skipped_lines << line.line_number
      end
    end

    if skipped_lines.any?
      print_skipped_lines(skipped_lines)
    end

    puts(<<~LOG.squish)
      ----
      Line coverage: #{colorized_coverage(sourcefile.covered_percent)}
      |
      Uncovered branches: #{colorized_uncovered_branches(uncovered_branches(sourcefile).size)}
      ----
    LOG
  end

  def print_skipped_lines(skipped_lines)
    divider = ' -' * 40

    # If we are skipping lines because they aren't in an env var specified
    # range, they might or might not be covered. If we are skipping them
    # otherwise, it's because they're covered.
    skipped_lines_adjective = ENV.fetch('SIMPLECOV_TERMINAL_LINES', nil).present? ? '' : 'covered '

    puts(line_printer.numbered_line_output(nil, :white, divider))
    puts(
      line_printer.numbered_line_output(
        nil,
        :white,
        "#{skipped_lines.size} #{skipped_lines_adjective}line(s) omitted".center(80, ' '),
      ),
    )
    puts(line_printer.numbered_line_output(nil, :white, divider))
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

  def print_info_for_undeterminable_application_target
    puts(<<~LOG.squish)
      Not showing test coverage details because "#{executed_spec_file}" cannot
      be mapped to a single application file.
    LOG
    puts(<<~LOG.squish)
      Tip: you can specify a file manually via a SIMPLECOV_TARGET_FILE environment variable.
    LOG
  end

  def print_info_for_undetermined_application_target
    puts(<<~LOG.squish)
      Not showing test coverage details because we could not map "#{executed_spec_file}"
      to an application file.
    LOG
    puts(<<~LOG.squish)
      Tip: You can provide a mapping via
      `SimpleCov::Formatter::Terminal.config.spec_to_app_file_map`.
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

  def print_line?(line_number)
    line_numbers_to_print.include?(line_number)
  end

  def sourcefile
    @sourcefile ||= @result.files.find { it.filename.end_with?(targeted_application_file) }
  end

  memo_wise \
  def line_numbers_to_print
    max_line_number = sourcefile.lines.map(&:line_number).max

    begin
      if (env_var_line_ranges = ENV.fetch('SIMPLECOV_TERMINAL_LINES', nil)).present?
        env_var_line_ranges.split(',').reduce([]) do |total_lines, env_var_line_range|
          lines_start, lines_end = env_var_line_range.split('-').map { Integer(it) }
          total_lines + (lines_start..lines_end).to_a
        end
      else
        case SimpleCov::Formatter::Terminal.config.lines_to_print.to_sym
        in SimpleCov::Formatter::Terminal::Config::LinesToPrint::ALL
          (1..max_line_number).to_a
        in SimpleCov::Formatter::Terminal::Config::LinesToPrint::UNCOVERED
          line_numbers_to_print = []

          sourcefile.lines.each do |line|
            if (
              line.coverage.nil? || (
                (line.coverage > 0) &&
                  !line_numbers_with_missing_branches(sourcefile).include?(line.line_number)
              )
            )
              next
            end

            line_number = line.line_number
            contextualized_line_numbers =
              ((line_number - 2)..(line_number + 2)).
                to_a.
                select do |context_line_number|
                  context_line_number.positive? && context_line_number <= max_line_number
                end
            line_numbers_to_print += contextualized_line_numbers
          end

          line_numbers_to_print
        end
      end
    end.to_set
  end

  memo_wise \
  def line_printer
    SimpleCov::Formatter::Terminal::LinePrinter.new(targeted_application_file)
  end
end
