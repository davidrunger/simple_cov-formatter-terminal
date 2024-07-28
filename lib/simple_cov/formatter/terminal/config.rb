# frozen_string_literal: true

require_relative 'spec_to_app_mapping'
require 'memo_wise'

class SimpleCov::Formatter::Terminal::Config < Runger::Config
  prepend MemoWise
  include SimpleCov::Formatter::Terminal::SpecToAppMapping

  module LinesToPrint
    ALL = :all
    UNCOVERED = :uncovered
  end

  attr_config(
    lines_to_print: LinesToPrint::UNCOVERED,
    spec_to_app_file_map:
      SimpleCov::Formatter::Terminal::SpecToAppMapping.default_spec_to_app_map,
    terminal_hyperlink_target_pattern: nil,
    unmappable_spec_regexes:
      SimpleCov::Formatter::Terminal::SpecToAppMapping::DEFAULT_UNMAPPABLE_SPEC_REGEXES,
  )
end
