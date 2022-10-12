# frozen_string_literal: true

require 'simplecov'
if ENV.fetch('CI', nil) == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
elsif (executed_spec_files = ARGV.grep(%r{\Aspec/.+_spec\.rb})).size == 1
  require 'simple_cov/formatter/terminal'
  SimpleCov.formatter = SimpleCov::Formatter::Terminal
  SimpleCov::Formatter::Terminal.executed_spec_file = executed_spec_files.first
  SimpleCov::Formatter::Terminal.spec_file_to_application_file_map = {
    %r{\Aspec/} => 'lib/',
  }
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
