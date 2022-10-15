# frozen_string_literal: true

require_relative 'terminal/version'
require 'active_support/core_ext/string/filters'
require 'memoist'
require 'rouge'
require 'rspec/core'

class SimpleCov::Formatter::Terminal
  extend Memoist

  # rubocop:disable Lint/OrAssignmentToConstant
  SPEC_TO_APP_DEFAULT_MAP ||= {
    %r{\Aspec/lib/} => 'lib/',
    %r{\Aspec/controllers/admin/(.*)_controller_spec.rb} => 'app/admin/\1.rb',
    %r{
      \Aspec/
      (
      actions|
      channels|
      controllers|
      decorators|
      helpers|
      mailboxes|
      mailers|
      models|
      policies|
      serializers|
      views|
      workers
      )
      /
    }x => 'app/\1/',
  }.freeze
  SPEC_TO_GEM_DEFAULT_MAP ||= {
    %r{\Aspec/} => 'lib/',
  }.freeze
  DEFAULT_UNMAPPABLE_SPEC_REGEXES ||= [
    %r{\Aspec/features/},
  ].freeze
  # rubocop:enable Lint/OrAssignmentToConstant

  class << self
    extend Memoist

    attr_accessor(
      :executed_spec_files,
      :failure_occurred,
      :spec_file_to_application_file_map,
      :unmappable_spec_regexes,
    )

    def setup_rspec
      return if @rspec_is_set_up # :nocov-else:

      # We can't easily test this, since we use this library in its own RSpec tests,
      # so we'd be setting it up twice if we tested it, which would be a bit of a problem.
      # :nocov:
      _setup_rspec
      @rspec_is_set_up = true
      # :nocov:
    end

    private

    def _setup_rspec
      RSpec.configure do |config|
        config.before(:suite) do
          SimpleCov::Formatter::Terminal.failure_occurred = false
        end

        config.after(:suite) do
          examples = RSpec.world.filtered_examples.values.flatten
          SimpleCov::Formatter::Terminal.failure_occurred = examples.any?(&:exception)
          SimpleCov::Formatter::Terminal.executed_spec_files =
            examples.map { _1.file_path.delete_prefix('./') }.uniq
        end
      end
    end

    def gem?
      Dir['*'].any? { _1.end_with?('.gemspec') }
    end

    def default_map
      # dup the maps because the maps are frozen but we want to allow the user to customize them
      gem? ? SPEC_TO_GEM_DEFAULT_MAP.dup : SPEC_TO_APP_DEFAULT_MAP.dup
    end
  end

  self.spec_file_to_application_file_map ||= default_map
  self.unmappable_spec_regexes ||= DEFAULT_UNMAPPABLE_SPEC_REGEXES

  def format(result)
    if self.class.executed_spec_files.nil?
      print_info_for_no_executed_specs
    elsif targeted_application_file.nil?
      print_info_for_undetermined_application_target
    elsif File.exist?(targeted_application_file)
      write_target_info_file if write_target_info_file?
      print_coverage_info(result)
    else
      print_info_for_nonexistent_application_target
    end
  end

  private

  memoize \
  def write_target_info_file?
    ENV.fetch('SIMPLECOV_WRITE_TARGET_TO_FILE', nil) == '1'
  end

  def write_target_info_file
    directory = 'tmp/simple_cov/formatter/terminal'
    FileUtils.mkdir_p(directory)
    File.write("#{directory}/target.txt", "#{targeted_application_file}\n")
  end

  def print_coverage_info(result)
    sourcefile = result.files.find { _1.filename.end_with?(targeted_application_file) }
    force_coverage = ENV.fetch('SIMPLECOV_FORCE_DETAILS', nil) == '1'

    if sourcefile.nil?
      puts(<<~LOG.squish)
        No code coverage info was found for "#{targeted_application_file}". Try stopping and
        disabling `spring`, if you are using it, and then rerun the spec.
      LOG
    elsif self.class.failure_occurred && !force_coverage
      puts(<<~LOG.squish)
        Test coverage: #{colorized_coverage(sourcefile.covered_percent)}.
        Not showing detailed test coverage because an example failed.
      LOG
    elsif sourcefile.covered_percent < 100 || uncovered_branches(sourcefile).any? || force_coverage
      print_coverage_details(sourcefile)
    else
      print_coverage_summary(sourcefile)
    end
  end

  def print_coverage_summary(sourcefile)
    summary = +"Test coverage is #{colorized_coverage(sourcefile.covered_percent)} "
    if SimpleCov.branch_coverage?
      summary << <<~LOG.squish
        and there are
        #{colorized_uncovered_branches(uncovered_branches(sourcefile).size)} uncovered branches
      LOG
    end
    summary << " for #{targeted_application_file}. Good job!"
    puts(summary.squish)
  end

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

  def executed_spec_file
    if self.class.executed_spec_files.size == 1
      self.class.executed_spec_files.first
    else
      raise(<<~ERROR)
        Multiple spec files were executed (#{self.class.executed_spec_files}), but
        SimpleCov::Formatter::Terminal only works when a single spec file is executed.
      ERROR
    end
  end

  def spec_file_to_application_file_map
    self.class.spec_file_to_application_file_map
  end

  def unmappable_spec_regexes
    self.class.unmappable_spec_regexes
  end

  memoize \
  def targeted_application_file
    env_variable_file = ENV.fetch('SIMPLECOV_TARGET_FILE', nil)
    if !env_variable_file.nil?
      puts('Determined targeted application file from SIMPLECOV_TARGET_FILE environment variable!!')
      return env_variable_file
    end

    return nil if unmappable_spec_regexes.any? { executed_spec_file.match?(_1) }

    spec_file_to_application_file_map.lazy.filter_map do |spec_file_regex, app_file_substitution|
      if executed_spec_file.match?(spec_file_regex)
        executed_spec_file.sub(spec_file_regex, app_file_substitution)
      end
    end.first&.sub(/_spec\.rb\z/, '.rb') ||
    raise("Could not map executed spec file #{executed_spec_file} to application file!")
  end

  def colored_line(line, sourcefile)
    colored_source_code = syntax_highlighted_source_lines[line.line_number - 1]
    missed_branch_info = missed_branch_info(line, sourcefile)
    line_number = line.line_number

    case
    when line.skipped?
      numbered_line_output(line_number, :white, colored_source_code)
    when line.coverage == 0
      numbered_line_output(line_number, :white_on_red, colored_source_code)
    when !missed_branch_info.empty?
      numbered_line_output(line_number, :red_on_yellow, colored_source_code, missed_branch_info)
    when line.coverage.nil?
      numbered_line_output(line_number, :white, colored_source_code, missed_branch_info)
    else
      numbered_line_output(line_number, :green, colored_source_code, missed_branch_info)
    end
  end

  # rubocop:disable Style/StringConcatenation
  def numbered_line_output(line_number, color, source_code, missed_branch_info = nil)
    colored_space =
      case color
      when :red_on_yellow, :white_on_red then color(' ', color)
      else color(' ', :white_on_green)
      end

    line_number_string =
      if write_target_info_file?
        ":::#{line_number}".rjust(6, ' ')
      else
        line_number.to_s.rjust(3, ' ')
      end

    output =
      colored_space +
      color(line_number_string, color) +
      colored_space +
      ' ' +
      source_code

    if missed_branch_info
      output << " #{color(missed_branch_info, :white_on_red)}"
    end

    output
  end
  # rubocop:enable Style/StringConcatenation

  def missed_branch_info(line, sourcefile)
    uncovered_branches(sourcefile).
      select { _1.start_line == line.line_number }.
      map { _1.type.to_s }.
      join(', ')
  end

  memoize \
  def syntax_highlighted_source_lines
    source = File.read(targeted_application_file)
    formatter = Rouge::Formatters::Terminal256.new(Rouge::Themes::Base16.mode(:dark).new)
    lexer = Rouge::Lexers::Ruby.new
    highlighted_source = formatter.format(lexer.lex(source))
    highlighted_source.split("\n")
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def color(message, color)
    case color
    when :white then "\e[0;37;49m#{message}\e[0m"
    when :red then "\e[0;31m#{message}\e[0m"
    when :green then "\e[1;32;49m#{message}\e[0m"
    when :yellow then "\e[0;33m#{message}\e[0m"
    when :white_on_green then "\e[1;39;102m#{message}\e[0m"
    when :red_on_yellow then "\e[0;31;103m#{message}\e[0m"
    when :white_on_red then "\e[1;37;41m#{message}\e[0m"
    else raise("Unknown color format '#{color}'.")
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

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
end

SimpleCov::Formatter::Terminal.setup_rspec
