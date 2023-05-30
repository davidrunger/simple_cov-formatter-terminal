# frozen_string_literal: true

require 'memo_wise'

class SimpleCov::Formatter::Terminal::FileDeterminer
  prepend MemoWise

  memo_wise \
  def executed_spec_file
    if executed_spec_files.size == 1
      executed_spec_files.first
    else
      raise(<<~ERROR)
        Multiple spec files were executed (#{executed_spec_files}), but
        SimpleCov::Formatter::Terminal only works when a single spec file is executed.
      ERROR
    end
  end

  memo_wise \
  def targeted_application_file
    env_variable_file = ENV.fetch('SIMPLECOV_TARGET_FILE', nil)
    if !env_variable_file.nil?
      puts('Determined targeted application file from SIMPLECOV_TARGET_FILE environment variable!!')
      return env_variable_file
    end

    return nil if unmappable_spec_regexes.any? { executed_spec_file.match?(_1) }

    spec_to_app_file_map.lazy.filter_map do |spec_file_regex, app_file_substitution|
      if executed_spec_file.match?(spec_file_regex)
        executed_spec_file.sub(spec_file_regex, app_file_substitution)
      end
    end.first&.sub(/_spec\.rb\z/, '.rb') ||
    raise("Could not map executed spec file #{executed_spec_file} to application file!")
  end

  memo_wise \
  def executed_spec_files
    SimpleCov::Formatter::Terminal::RSpecIntegration.executed_spec_files
  end

  memo_wise \
  def spec_to_app_file_map
    SimpleCov::Formatter::Terminal.config.spec_to_app_file_map ||
    SimpleCov::Formatter::Terminal::SpecToAppMapping.default_spec_to_app_map
  end

  memo_wise \
  def unmappable_spec_regexes
    SimpleCov::Formatter::Terminal.config.unmappable_spec_regexes
  end
end
