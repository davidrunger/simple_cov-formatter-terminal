# frozen_string_literal: true

require_relative 'terminal/version'
require 'active_support/core_ext/string/filters'
require 'memoist'
require 'rouge'

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
  SPEC_TO_GEM_DEFAULT_MAP = {
    %r{\Aspec/} => 'lib/',
  }.freeze
  DEFAULT_UNMAPPABLE_SPEC_REGEXES ||= [
    %r{\Aspec/features/},
  ].freeze
  # rubocop:enable Lint/OrAssignmentToConstant

  class << self
    extend Memoist

    attr_accessor(
      :executed_spec_file,
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
    if self.class.failure_occurred
      puts(<<~LOG.squish)
        Test coverage: #{colorized_coverage(sourcefile.covered_percent)}.
        Not showing detailed test coverage because an example failed.
      LOG
    elsif sourcefile.covered_percent < 100
      print_coverage_details(sourcefile)
    else
      puts(<<~LOG.squish)
        Test coverage is #{colorized_coverage(sourcefile.covered_percent)}
        for #{targeted_application_file}. Good job!
      LOG
    end
  end

  def print_coverage_details(sourcefile)
    header = "-- Coverage for #{targeted_application_file} --------"
    puts(header)
    sourcefile.lines.each do |line|
      puts(colored_line(line))
    end
    message = "-- Coverage: #{colorized_coverage(sourcefile.covered_percent)} "
    puts("#{message}#{'-' * (header.size - message.size)}")
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
    self.class.executed_spec_file
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
      puts('Determined targeted application file from SIMPLECOV_TARGET_FILE environment variable.')
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

  def colored_line(line)
    source = syntax_highlighted_source_lines[line.line_number - 1]
    return "#{colored('░░ ', :gray)}#{source}" if line.skipped?

    case line.coverage
    when nil then "#{colored('░░ ', :gray)}#{source}"
    when (1..) then "#{colored('██ ', :green)}#{source}"
    when 0 then "#{colored('██ ', :red)}#{source}"
    end
  end

  memoize \
  def syntax_highlighted_source_lines
    source = File.read(targeted_application_file)
    formatter = Rouge::Formatters::Terminal256.new(Rouge::Themes::Base16.mode(:dark).new)
    lexer = Rouge::Lexers::Ruby.new
    highlighted_source = formatter.format(lexer.lex(source))
    highlighted_source.split("\n")
  end

  def colored(message, color)
    case color
    when :gray then "\e[0;30m#{message}\e[0m"
    when :red then "\e[0;31m#{message}\e[0m"
    when :green then "\e[0;32m#{message}\e[0m"
    when :yellow then "\e[0;33m#{message}\e[0m"
    end
  end

  def colorized_coverage(covered_percent)
    case
    when covered_percent < 80 then colored("#{covered_percent.round(2)}%", :red)
    when covered_percent < 100 then colored("#{covered_percent.round(2)}%", :yellow)
    when covered_percent >= 100 then colored("#{covered_percent.round(2)}%", :green)
    end
  end
end

SimpleCov::Formatter::Terminal.setup_rspec
