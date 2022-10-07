# frozen_string_literal: true

require 'simplecov'
executed_spec_files = ARGV.grep(%r{\Aspec/.+_spec\.rb})
if ENV.fetch('CI', nil) == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
elsif executed_spec_files.size == 1
  require 'simple_cov/formatter/terminal'
  SimpleCov::Formatter::Terminal.executed_spec_files = executed_spec_files
  SimpleCov.formatter = SimpleCov::Formatter::Terminal
end
SimpleCov.start do
  add_filter(%r{\A/spec/})
end

load 'simple_cov/formatter/terminal.rb'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with(:rspec) do |c|
    c.syntax = :expect
  end
end
