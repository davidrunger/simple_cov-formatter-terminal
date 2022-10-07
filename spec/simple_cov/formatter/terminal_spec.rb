# frozen_string_literal: true

RSpec.describe SimpleCov::Formatter::Terminal do
  it 'has a version number' do
    expect(SimpleCov::Formatter::Terminal::VERSION).not_to be(nil)
  end
end
