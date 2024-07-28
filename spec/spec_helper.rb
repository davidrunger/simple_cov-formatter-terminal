# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter(%r{\A/spec/})
  enable_coverage(:branch)
end
require 'simple_cov/formatter/terminal'
if ENV.fetch('CI', nil) == 'true'
  require 'simplecov-cobertura'
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
  SimpleCov.coverage_dir('tmp/simple_cov') # must match codecov-action directory option
elsif RSpec.configuration.files_to_run.one?
  SimpleCov.formatter = SimpleCov::Formatter::Terminal
  SimpleCov::Formatter::Terminal.config.terminal_hyperlink_target_pattern = 'vscode://file/%f:%l'
end
require 'climate_control'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with(:rspec) do |c|
    c.syntax = :expect
  end

  config.mock_with(:rspec) do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run_when_matching(:focus)

  config.order = :random

  config.before(:each) do
    SimpleCov::Formatter::Terminal.config.reset_memo_wise
  end
end
