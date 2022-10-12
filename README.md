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
if (executed_spec_files = ARGV.grep(%r{\Aspec/.+_spec\.rb})).size == 1
  require 'simple_cov/formatter/terminal'
  SimpleCov.formatter = SimpleCov::Formatter::Terminal
  SimpleCov::Formatter::Terminal.executed_spec_file = executed_spec_files.first
end
SimpleCov.start do
  add_filter(%r{^/spec/})
end
```

Note that `SimpleCov::Formatter::Terminal` will only be used when specs are run with a single spec
file (e.g. `bin/rspec spec/models/user_spec.rb`) and not when multiple specs are executed (e.g. when
simply running `bin/rspec` without any argument).

### Modifying the `spec_file_to_application_file_map`

`SimpleCov::Formatter::Terminal` has a default hash that is used to map spec files to their
corresponding application file. This default is optimized for Rails applications using Active Admin.

```rb
SimpleCov::Formatter::Terminal.spec_file_to_application_file_map = {
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
SimpleCov::Formatter::Terminal.spec_file_to_application_file_map.merge!(
  %r{\Aspec/my_special/directory_structure/} => 'my_special/app_directory/',
)
```

Or you can override the default mapping completely:

```rb
SimpleCov::Formatter::Terminal.spec_file_to_application_file_map = {
  %r{\Aspec/my_special/directory_structure/} => 'my_special/app_directory/',
}
```

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
