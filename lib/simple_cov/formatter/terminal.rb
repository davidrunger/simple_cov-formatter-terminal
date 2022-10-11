# frozen_string_literal: true

require_relative 'terminal/version'
require 'active_support/core_ext/string/filters'
require 'amazing_print'
require 'memoist'
require 'rouge'

class SimpleCov::Formatter::Terminal
  extend Memoist

  class << self
    attr_accessor :executed_spec_files
  end

  def format(result)
    number_of_spec_files = self.class.executed_spec_files.size
    if number_of_spec_files == 1 && File.exist?(targeted_application_file)
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
    elsif number_of_spec_files != 1
      puts(
        "Can't determine the targeted application file because the number " \
        "of executed spec files is not 1 (it's #{number_of_spec_files})!",
      )
    else
      puts(<<~LOG.squish)
        Cannot show code coverage. Looked for application file "#{targeted_application_file}",
        but it does not exist.
      LOG
    end
  end

  private

  memoize \
  def targeted_application_file
    spec_file = self.class.executed_spec_files.first
    case spec_file
    when %r{\Aspec/lib/}
      spec_file.
        sub(%r{spec/lib/}, 'lib/').
        sub(/_spec\.rb\z/, '.rb')
    else
      spec_file.
        sub(%r{spec/}, 'lib/').
        sub(/_spec\.rb\z/, '.rb')
    end
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
