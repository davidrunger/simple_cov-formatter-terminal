# SimpleCov::Formatter::Terminal

![image](https://user-images.githubusercontent.com/8197963/194628739-7f51e575-0c74-4325-87b7-a0422b9548a1.png)

## Installation

Add the gem to your application's `Gemfile`. Because the gem is not released via RubyGems, you will
need to install it from GitHub.

```rb
group :test do
  gem 'simple_cov-formatter-terminal', github: 'davidrunger/simple_cov-formatter-terminal'
end
```

And then execute:

```
$ bundle install
```

## Usage

Add something like the following to your `spec/spec_helper.rb` file:

```rb
require 'simplecov'
executed_spec_files = ARGV.grep(%r{\Aspec/.+_spec\.rb})
if executed_spec_files.size == 1
  require 'simple_cov/formatter/terminal'
  SimpleCov::Formatter::Terminal.executed_spec_files = executed_spec_files
  SimpleCov.formatter = SimpleCov::Formatter::Terminal
end
SimpleCov.start do
  add_filter(%r{^/spec/})
end
```

Note that `SimpleCov::Formatter::Terminal` will only be used when specs are run with a single spec
file (e.g. `bin/rspec spec/models/user_spec.rb`) and not when multiple specs are executed (e.g. when
simply running `bin/rspec` without any argument).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/rspec` to run
the tests. You can also run `bin/console` for an interactive prompt that will allow you to
experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/davidrunger/simple_cov-formatter-terminal.

## License

The gem is available as open source under the terms of the [MIT
License](https://opensource.org/licenses/MIT).
