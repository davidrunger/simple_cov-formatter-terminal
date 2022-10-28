# frozen_string_literal: true

require 'memoist'

module TargetFile
  extend Memoist

  memoize \
  def write_target_info_file?
    ENV.fetch('SIMPLECOV_WRITE_TARGET_TO_FILE', nil) == '1'
  end

  def write_target_info_file
    directory = 'tmp/simple_cov/formatter/terminal'
    FileUtils.mkdir_p(directory)
    File.write("#{directory}/target.txt", "#{targeted_application_file}\n")
  end
end
