# frozen_string_literal: true

module SimpleCov::Formatter::Terminal::RailsAwareness
  class << self
    def rails?
      !!defined?(Rails)
    end
  end
end
