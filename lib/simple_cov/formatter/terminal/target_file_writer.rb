# frozen_string_literal: true

require 'memoist'

class SimpleCov::Formatter::Terminal::TargetFileWriter
  def initialize(targeted_application_file)
    @targeted_application_file = targeted_application_file
  end

  def write_target_info_file
    directory = 'tmp/simple_cov/formatter/terminal'
    FileUtils.mkdir_p(directory)
    File.write("#{directory}/target.txt", "#{@targeted_application_file}\n")
  end
end
