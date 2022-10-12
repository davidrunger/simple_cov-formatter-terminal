# frozen_string_literal: true

require_relative 'terminal/version'
require 'active_support/core_ext/string/filters'
require 'memoist'
require 'rouge'

class SimpleCov::Formatter::Terminal
  extend Memoist

  # rubocop:disable Lint/OrAssignmentToConstant
  DEFAULT_SPEC_TO_APP_MAP ||= {
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
  # rubocop:enable Lint/OrAssignmentToConstant

  class << self
    attr_accessor :executed_spec_file, :failure_occurred, :spec_file_to_application_file_map

    def setup_rspec
      return if @rspec_is_set_up

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

      @rspec_is_set_up = true
    end
  end

  if spec_file_to_application_file_map.nil?
    self.spec_file_to_application_file_map = DEFAULT_SPEC_TO_APP_MAP
  end

  def format(result)
    if File.exist?(targeted_application_file)
      sourcefile = result.files.find { _1.filename.end_with?(targeted_application_file) }
      if self.class.failure_occurred
        puts(<<~LOG.squish)
          Test coverage: #{colorized_coverage(sourcefile.covered_percent)}.
          Not showing detailed test coverage because an example failed.
        LOG
      elsif sourcefile.covered_percent < 100
        header = "-- Coverage for #{targeted_application_file} --------"
        puts(header)
        sourcefile.lines.each do |line|
          puts(colored_line(line))
        end
        message = "-- Coverage: #{colorized_coverage(sourcefile.covered_percent)} "
        puts("#{message}#{'-' * (header.size - message.size)}")
      else
        puts(<<~LOG.squish)
          Test coverage is #{colorized_coverage(sourcefile.covered_percent)}
          for #{targeted_application_file}. Good job!
        LOG
      end
    else
      puts(<<~LOG.squish)
        Cannot show code coverage. Looked for application file "#{targeted_application_file}",
        but it does not exist.
      LOG
    end
  end

  private

  def executed_spec_file
    self.class.executed_spec_file
  end

  def spec_file_to_application_file_map
    self.class.spec_file_to_application_file_map
  end

  memoize \
  def targeted_application_file
    spec_file_to_application_file_map.lazy.filter_map do |spec_file_regex, app_file_substitution|
      if executed_spec_file.match?(spec_file_regex)
        executed_spec_file.sub(spec_file_regex, app_file_substitution)
      end
    end.first&.sub(/_spec\.rb\z/, '.rb') ||
    raise("Could not map executed spec file #{executed_spec_file} to application file!")
  end

  def colored_line(line)
    source = syntax_highlighted_source_lines[line.line_number - 1]
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
