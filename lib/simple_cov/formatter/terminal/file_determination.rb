# frozen_string_literal: true

require 'memoist'

module FileDetermination
  extend Memoist

  def executed_spec_file
    if self.class.executed_spec_files.size == 1
      self.class.executed_spec_files.first
    else
      raise(<<~ERROR)
        Multiple spec files were executed (#{self.class.executed_spec_files}), but
        SimpleCov::Formatter::Terminal only works when a single spec file is executed.
      ERROR
    end
  end

  def spec_file_to_application_file_map
    self.class.spec_file_to_application_file_map
  end

  def unmappable_spec_regexes
    self.class.unmappable_spec_regexes
  end

  memoize \
  def targeted_application_file
    env_variable_file = ENV.fetch('SIMPLECOV_TARGET_FILE', nil)
    if !env_variable_file.nil?
      puts('Determined targeted application file from SIMPLECOV_TARGET_FILE environment variable!!')
      return env_variable_file
    end

    return nil if unmappable_spec_regexes.any? { executed_spec_file.match?(_1) }

    spec_file_to_application_file_map.lazy.filter_map do |spec_file_regex, app_file_substitution|
      if executed_spec_file.match?(spec_file_regex)
        executed_spec_file.sub(spec_file_regex, app_file_substitution)
      end
    end.first&.sub(/_spec\.rb\z/, '.rb') ||
    raise("Could not map executed spec file #{executed_spec_file} to application file!")
  end
end
