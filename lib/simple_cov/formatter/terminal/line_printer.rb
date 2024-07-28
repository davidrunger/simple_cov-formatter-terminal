# frozen_string_literal: true

require 'memo_wise'

class SimpleCov::Formatter::Terminal::LinePrinter
  prepend MemoWise
  include SimpleCov::Formatter::Terminal::BranchCoverage
  include SimpleCov::Formatter::Terminal::ColorPrinting

  LINE_NUMBER_WIDTH = 3

  def initialize(targeted_application_file = nil)
    @targeted_application_file = targeted_application_file
  end

  def colored_line(line, sourcefile)
    colored_source_code = syntax_highlighted_source_lines[line.line_number - 1]
    line_number = line.line_number

    case
    when line.skipped?
      numbered_line_output(line_number, :white, colored_source_code)
    when line.coverage == 0
      numbered_line_output(line_number, :white_on_red, colored_source_code)
    when (missed_branch_info = missed_branch_info(line, sourcefile))
      numbered_line_output(line_number, :red_on_yellow, colored_source_code, missed_branch_info)
    when line.coverage.nil?
      numbered_line_output(line_number, :white, colored_source_code, missed_branch_info)
    else
      numbered_line_output(line_number, :green, colored_source_code, missed_branch_info)
    end
  end

  # rubocop:disable Style/StringConcatenation
  def numbered_line_output(line_number, color, source_code = '', missed_branch_info = nil)
    colored_space =
      case color
      when :red_on_yellow, :white_on_red then color(' ', color)
      else color(' ', :white_on_green)
      end

    pattern = SimpleCov::Formatter::Terminal.config.terminal_hyperlink_target_pattern

    link_text = line_number.to_s.rjust(LINE_NUMBER_WIDTH, ' ')

    line_number_string =
      if pattern
        link_target = pattern.sub('%f', absolute_target_path).sub('%l', line_number.to_s)
        "\e]8;;#{link_target}\e\\#{link_text}\e]8;;\e\\"
      else
        link_text
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

  memo_wise \
  def syntax_highlighted_source_lines
    source = File.read(@targeted_application_file)
    formatter = Rouge::Formatters::Terminal256.new(Rouge::Themes::Base16.mode(:dark).new)
    lexer = Rouge::Lexers::Ruby.new
    highlighted_source = formatter.format(lexer.lex(source))
    highlighted_source.split("\n")
  end

  private

  memo_wise \
  def absolute_target_path
    File.join(ENV.fetch('PWD'), @targeted_application_file)
  end
end
