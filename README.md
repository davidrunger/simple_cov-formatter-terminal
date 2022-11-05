# SimpleCov::Formatter::Terminal

![image](https://user-images.githubusercontent.com/8197963/195740768-e2cbb99d-7cf2-42bf-a178-2f78eb653dd3.png)

## Installation

*Note:* This gem depends upon RSpec. If you aren't using RSpec to run your tests, it won't work!

Add the gem to your application's `Gemfile`. Because the gem is not released via RubyGems, you will
need to install it from GitHub.

```rb
group :test do
  gem 'simple_cov-formatter-terminal', github: 'davidrunger/simple_cov-formatter-terminal'
end
```

Then execute:

```
$ bundle install
```

Then continue to the "Usage" section below.

## Usage

Add something like the following to your `spec/spec_helper.rb` file:

```rb
require 'simplecov'
if RSpec.configuration.files_to_run.one?
  require 'simple_cov/formatter/terminal'
  SimpleCov.formatter = SimpleCov::Formatter::Terminal
end
SimpleCov.start
```

**Note** that this setup only uses `SimpleCov::Formatter::Terminal` when specs are run with a single
spec file (e.g. `bin/rspec spec/models/user_spec.rb`) and not when multiple specs are executed (e.g.
when simply running `bin/rspec` without any argument).

### Modifying the `spec_to_app_file_map`

`SimpleCov::Formatter::Terminal` has a default hash that is used to map spec files to their
corresponding application file.

For gems (determined from whether there is a `.gemspec` file at the top level of the project), the
default mapping is very simple:

```rb
SimpleCov::Formatter::Terminal.config.spec_to_app_file_map = {
  %r{\Aspec/} => 'lib/',
}
```

This is the default used for non-gems; it is optimized for Rails applications using Active Admin:

```rb
SimpleCov::Formatter::Terminal.config.spec_to_app_file_map = {
  %r{\Aspec/lib/} => 'lib/',
  %r{\Aspec/controllers/admin/(.*)_controller_spec.rb} => 'app/admin/\1.rb',
  %r{
    \Aspec/
    (
    actions|
    channels|
    controllers|
    decorators|
    helpers|
    mailboxes|
    mailers|
    models|
    policies|
    serializers|
    views|
    workers
    )
    /
  }x => 'app/\1/',
}
```

If needed for your application, you can add to this hash in your `spec/spec_helper.rb`, e.g.:

```rb
SimpleCov::Formatter::Terminal.config.spec_to_app_file_map.merge!(
  %r{\Aspec/my_special/directory_structure/} => 'my_special/app_directory/',
)
```

Or you can override the default mapping completely:

```rb
SimpleCov::Formatter::Terminal.config.spec_to_app_file_map = {
  %r{\Aspec/my_special/directory_structure/} => 'my_special/app_directory/',
}
```

## Branch coverage

If you enable branch coverage for SimpleCov (via `enable_coverage(:branch)` within your
`SimpleCov.start` block; read more [here][simple-cov-branch-coverage]), then branch coverage info
will be included in SimpleCov::Formatter::Terminal's output. Missed branches will be indicated with
white text on a red background at the end of the line, and the line number will be printed in red
text on a yellow background, as seen in the screenshot at the top of this README (where a `then`
branch is not covered on line 18).

[simple-cov-branch-coverage]: https://github.com/simplecov-ruby/simplecov#branch-coverage-ruby--25

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
