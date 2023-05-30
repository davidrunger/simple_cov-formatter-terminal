# frozen_string_literal: true

class SimpleCov::Formatter::Terminal ; end # rubocop:disable Lint/EmptyClass

require_relative 'terminal/config'
require_relative 'terminal/file_determiner'
require_relative 'terminal/r_spec_integration'
require_relative 'terminal/result_printer'
require_relative 'terminal/version'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/filters'
require 'memoist'
require 'rouge'
require 'rspec/core'
require 'simplecov'

class SimpleCov::Formatter::Terminal
  extend Forwardable
  prepend MemoWise

  def_delegators(
    :file_determiner,
    :executed_spec_file,
    :executed_spec_files,
    :targeted_application_file,
  )
  def_delegators(
    :result_printer,
    :print_coverage_info,
    :print_info_for_no_executed_specs,
    :print_info_for_nonexistent_application_target,
    :print_info_for_undetermined_application_target,
  )

  class << self
    prepend MemoWise

    memo_wise \
    def config
      Config.new
    end
  end

  def format(result)
    if executed_spec_files.nil?
      print_info_for_no_executed_specs
    elsif targeted_application_file.nil?
      print_info_for_undetermined_application_target
    elsif File.exist?(targeted_application_file)
      print_coverage_info(result)
    else
      print_info_for_nonexistent_application_target
    end
  end

  private

  memo_wise \
  def file_determiner
    SimpleCov::Formatter::Terminal::FileDeterminer.new
  end

  memo_wise \
  def result_printer
    SimpleCov::Formatter::Terminal::ResultPrinter.new(file_determiner)
  end
end

SimpleCov::Formatter::Terminal::RSpecIntegration.setup_rspec
