# frozen_string_literal: true

require_relative 'terminal/version'
require 'active_support/core_ext/string/filters'
require 'memoist'
require 'rouge'

class SimpleCov::Formatter::Terminal
  extend Memoist

  # rubocop:disable Lint/OrAssignmentToConstant
  MAX_LINE_WIDTH ||= 100
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
      return if @rspec_is_set_up || !defined?(RSpec)

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
          if examples.any?(&:exception)
            SimpleCov::Formatter::Terminal.failure_occurred = true
          end
          SimpleCov::Formatter::Terminal.executed_spec_files =
            examples.map { _1.file_path.delete_prefix('./') }.uniq
        end
      end
    end

    def gem?
      Dir['*'].any? { _1.end_with?('.gemspec') }
    end

    def default_map
      gem? ? SPEC_TO_GEM_DEFAULT_MAP : SPEC_TO_APP_DEFAULT_MAP
    end
  end

  self.spec_file_to_application_file_map ||= default_map
  self.unmappable_spec_regexes ||= DEFAULT_UNMAPPABLE_SPEC_REGEXES

  def format(result)
    if targeted_application_file.nil?
      print_info_for_undetermined_application_target
    elsif File.exist?(targeted_application_file)
      print_coverage_info(result)
    else
      print_info_for_nonexistent_application_target
    end
  end

  private

  def print_coverage_info(result)
    sourcefile = result.files.find { _1.filename.end_with?(targeted_application_file) }
    if sourcefile.nil?
      puts(<<~LOG.squish)
        No code coverage info was found for "#{targeted_application_file}". Try stopping and
        disabling `spring`, if you are using it, and then rerun the spec.
      LOG
    elsif self.class.failure_occurred
      puts(<<~LOG.squish)
        Test coverage: #{colorized_coverage(sourcefile.covered_percent)}.
        Not showing detailed test coverage because an example failed.
      LOG
    elsif sourcefile.covered_percent < 100 || uncovered_branches(sourcefile).any?
      print_coverage_details(sourcefile)
    else
      puts(<<~LOG.squish)
        Test coverage is
        #{colorized_coverage(sourcefile.covered_percent)}
        and there are
        #{colorized_uncovered_branches(uncovered_branches(sourcefile).size)} uncovered branches
        for #{targeted_application_file}. Good job!
      LOG
    end
  end

  memoize \
  def uncovered_branches(sourcefile)
    sourcefile.branches.reject(&:covered?)
  end

  def print_coverage_details(sourcefile)
    header = "---- Coverage for #{targeted_application_file} ".ljust(MAX_LINE_WIDTH + 5, '-')
    puts(header)
    sourcefile.lines.each do |line|
      puts(colored_line(line, sourcefile))
    end
    puts((<<~LOG.squish + ' ').ljust(127, '-')) # rubocop:disable Style/StringConcatenation
      ----
      Line coverage: #{colorized_coverage(sourcefile.covered_percent)}
      |
      Uncovered branches: #{colorized_uncovered_branches(uncovered_branches(sourcefile).size)}
    LOG
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
    required_padding = [1 + MAX_LINE_WIDTH - line.source.rstrip.size, 0].max
    padding = ' ' * required_padding
    branch_info = missed_branch_info(line, sourcefile)
    if line.skipped?
      return full_line_output('░', :gray, colored_source_code, padding, branch_info)
    end

    case line.coverage
    when nil then full_line_output('░', :gray, colored_source_code, padding, branch_info)
    when (1..) then full_line_output('█', :green, colored_source_code, padding, branch_info)
    when 0 then full_line_output('█', :red, colored_source_code, padding, branch_info)
    end
  end

  def full_line_output(leading_box, box_color, source_code, padding, branch_info)
    # rubocop:disable Style/StringConcatenation
    color(leading_box * 2, box_color) +
      ' ' +
      source_code +
      padding +
      '| ' +
      color(branch_info, :red)
    # rubocop:enable Style/StringConcatenation
  end

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

  def color(message, color)
    case color
    when :gray then "\e[0;30m#{message}\e[0m"
    when :red then "\e[0;31m#{message}\e[0m"
    when :green then "\e[0;32m#{message}\e[0m"
    when :yellow then "\e[0;33m#{message}\e[0m"
    end
  end

  def colorized_coverage(covered_percent)
    case
    when covered_percent < 80 then color("#{covered_percent.round(2)}%", :red)
    when covered_percent < 100 then color("#{covered_percent.round(2)}%", :yellow)
    when covered_percent >= 100 then color("#{covered_percent.round(2)}%", :green)
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
