# frozen_string_literal: true

module SimpleCov::Formatter::Terminal::ColorPrinting
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
end
