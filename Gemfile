# frozen_string_literal: true

ruby file: '.ruby-version'

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in fcom.gemspec
gemspec

group :development, :test do
  gem 'bundler', require: false
  gem 'pry'
  gem 'pry-byebug', github: 'davidrunger/pry-byebug'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rspec', require: false
  gem 'runger_style', require: false
end

group :test do
  gem 'climate_control'
  gem 'rspec', require: false
  gem 'simplecov', require: false
  gem 'simplecov-cobertura', require: false
end

group :development do
  gem 'rake', require: false
  gem 'runger_release_assistant', require: false
end
