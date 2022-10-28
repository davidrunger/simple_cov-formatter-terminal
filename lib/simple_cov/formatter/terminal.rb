# frozen_string_literal: true

require_relative 'terminal/file_determination'
require_relative 'terminal/gem_awareness'
require_relative 'terminal/print_commands'
require_relative 'terminal/r_spec_integration'
require_relative 'terminal/spec_to_app_maps'
require_relative 'terminal/target_file'
require_relative 'terminal/version'
require 'active_support/core_ext/string/filters'
require 'memoist'
require 'rouge'
require 'rspec/core'

class SimpleCov::Formatter::Terminal
  extend Memoist
  include FileDetermination
  include PrintCommands
  include SpecToAppMaps
  include TargetFile

  class << self
    include GemAwareness
    include RSpecIntegration

    attr_accessor(
      :executed_spec_files,
      :failure_occurred,
      :spec_file_to_application_file_map,
      :unmappable_spec_regexes,
    )
  end

  self.spec_file_to_application_file_map ||= default_map
  self.unmappable_spec_regexes ||= DEFAULT_UNMAPPABLE_SPEC_REGEXES

  def format(result)
    if self.class.executed_spec_files.nil?
      print_info_for_no_executed_specs
    elsif targeted_application_file.nil?
      print_info_for_undetermined_application_target
    elsif File.exist?(targeted_application_file)
      write_target_info_file if write_target_info_file?
      print_coverage_info(result)
    else
      print_info_for_nonexistent_application_target
    end
  end
end

SimpleCov::Formatter::Terminal.setup_rspec
