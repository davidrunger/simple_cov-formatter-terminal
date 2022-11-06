# frozen_string_literal: true

RSpec.describe(SimpleCov::Formatter::Terminal::TargetFileWriter) do
  subject(:target_file_writer) do
    SimpleCov::Formatter::Terminal::TargetFileWriter.new(targeted_application_file)
  end

  let(:targeted_application_file) { 'an/application/file.rb' }

  describe '#write_target_info_file' do
    subject(:write_target_info_file) do
      target_file_writer.send(:write_target_info_file)
    end

    it 'writes the targeted file name to tmp/simple_cov/formatter/terminal/target.txt' do
      expect(File).
        to receive(:write).
        with('tmp/simple_cov/formatter/terminal/target.txt', "#{targeted_application_file}\n")

      write_target_info_file
    end
  end
end
