# frozen_string_literal: true

module RSpecIntegration
  def setup_rspec
    return if @rspec_is_set_up # :nocov-else:

    # We can't easily test this, since we use this library in its own RSpec tests,
    # so we'd be setting it up twice if we tested it, which would be a bit of a problem.
    # :nocov:
    _setup_rspec
    @rspec_is_set_up = true
    # :nocov:
  end

  private

  def _setup_rspec
    RSpec.configure do |config|
      config.before(:suite) do
        SimpleCov::Formatter::Terminal.failure_occurred = false
      end

      config.after(:suite) do
        examples = RSpec.world.filtered_examples.values.flatten
        SimpleCov::Formatter::Terminal.failure_occurred = examples.any?(&:exception)
        SimpleCov::Formatter::Terminal.executed_spec_files =
          examples.map { _1.file_path.delete_prefix('./') }.uniq
      end
    end
  end
end
