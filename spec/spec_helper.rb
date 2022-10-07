# frozen_string_literal: true

require 'simplecov'
if ENV.fetch('CI', nil) == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end
SimpleCov.start do
  add_filter(%r{\A/spec/})
end

require 'simple_cov/formatter/terminal'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with(:rspec) do |c|
    c.syntax = :expect
  end
end
