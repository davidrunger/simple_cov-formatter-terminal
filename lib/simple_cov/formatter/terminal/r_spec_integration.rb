# frozen_string_literal: true

module SimpleCov::Formatter::Terminal::RSpecIntegration
  class << self
    attr_accessor :executed_spec_files, :failure_occurred

    def setup_rspec
      return if @rspec_is_set_up # :nocov-else:

      # We can't easily test this, since we use this library in its own RSpec tests,
      # so we'd be setting it up twice if we tested it, which would be a bit of a problem.
      # :nocov:
      _setup_rspec
      @rspec_is_set_up = true
      # :nocov:
    end

    def failure_occurred?
      !!@failure_occurred
    end

    private

    def _setup_rspec
      RSpec.configure do |config|
        config.before(:suite) do
          SimpleCov::Formatter::Terminal::RSpecIntegration.failure_occurred = false
        end

        config.after(:suite) do
          examples = RSpec.world.filtered_examples.values.flatten
          SimpleCov::Formatter::Terminal::RSpecIntegration.failure_occurred =
            examples.any?(&:exception)
          SimpleCov::Formatter::Terminal::RSpecIntegration.executed_spec_files =
            examples.map { it.file_path.delete_prefix('./') }.uniq
        end
      end
    end
  end
end
