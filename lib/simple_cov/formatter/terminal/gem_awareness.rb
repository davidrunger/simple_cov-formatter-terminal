# frozen_string_literal: true

module SimpleCov::Formatter::Terminal::GemAwareness
  class << self
    def gem?
      Dir['*'].any? { _1.end_with?('.gemspec') }
    end
  end
end
