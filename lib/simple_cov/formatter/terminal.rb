# frozen_string_literal: true

require_relative 'terminal/version'
require 'active_support/core_ext/string/filters'
require 'amazing_print'
require 'memoist'
require 'rouge'

class SimpleCov::Formatter::Terminal
  extend Memoist

  class << self
    attr_accessor :executed_spec_file, :spec_file_to_application_file_map
  end

  self.spec_file_to_application_file_map = {
    %r{\Aspec/lib/} => 'lib/',
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
  }

  def format(result)
    if File.exist?(targeted_application_file)
      sourcefile = result.files.find { _1.filename.end_with?(targeted_application_file) }
      if sourcefile.covered_percent < 100
        header = "-- Coverage for #{targeted_application_file} --------"
        puts(header)
        sourcefile.lines.each do |line|
          puts(colored_line(line))
        end
        puts('-' * header.size)
      else
        puts("Test coverage is #{'100%'.green} for #{targeted_application_file}. Good job!")
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

  def targeted_application_file
    spec_file_to_application_file_map.lazy.filter_map do |spec_file_regex, app_file_substitution|
      if executed_spec_file.match?(spec_file_regex)
        executed_spec_file.sub(spec_file_regex, app_file_substitution)
      end
    end.first&.sub(/_spec\.rb\z/, '.rb') || raise('Could not map spec file to application file!')
  end

  def colored_line(line)
    source = syntax_highlighted_source_lines[line.line_number - 1]
    case line.coverage
    when nil then "#{'░░ '.gray}#{source}"
    when (1..) then "#{'██ '.green}#{source}"
    when 0 then "#{'██ '.red}#{source}"
    else raise('Unexpected coverage value!')
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
end
