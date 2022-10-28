# frozen_string_literal: true

require 'memoist'

module PrintUtils
  extend Memoist

  def colored_line(line, sourcefile)
    colored_source_code = syntax_highlighted_source_lines[line.line_number - 1]
    line_number = line.line_number

    case
    when line.skipped?
      numbered_line_output(line_number, :white, colored_source_code)
    when line.coverage == 0
      numbered_line_output(line_number, :white_on_red, colored_source_code)
    when !(missed_branch_info = missed_branch_info(line, sourcefile)).empty?
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

  memoize \
  def syntax_highlighted_source_lines
    source = File.read(targeted_application_file)
    formatter = Rouge::Formatters::Terminal256.new(Rouge::Themes::Base16.mode(:dark).new)
    lexer = Rouge::Lexers::Ruby.new
    highlighted_source = formatter.format(lexer.lex(source))
    highlighted_source.split("\n")
  end
end
