# frozen_string_literal: true

require_relative './spec_to_app_mapping'
require 'memoist'

class SimpleCov::Formatter::Terminal::Config
  extend Memoist
  include SimpleCov::Formatter::Terminal::SpecToAppMapping

  attr_accessor :spec_to_app_file_map, :unmappable_spec_regexes

  def initialize
    @spec_to_app_file_map =
      SimpleCov::Formatter::Terminal::SpecToAppMapping.default_spec_to_app_map
    @unmappable_spec_regexes =
      SimpleCov::Formatter::Terminal::SpecToAppMapping::DEFAULT_UNMAPPABLE_SPEC_REGEXES
  end

  memoize \
  def write_target_info_file?
    ENV.fetch('SIMPLECOV_WRITE_TARGET_TO_FILE', nil) == '1'
  end
end
