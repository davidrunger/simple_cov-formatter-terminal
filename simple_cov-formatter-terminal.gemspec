# frozen_string_literal: true

require_relative 'lib/simple_cov/formatter/terminal/version'

Gem::Specification.new do |spec|
  spec.name = 'simple_cov-formatter-terminal'
  spec.version = SimpleCov::Formatter::Terminal::VERSION
  spec.authors = ['David Runger']
  spec.email = ['davidjrunger@gmail.com']

  spec.summary = 'Print detailed code coverage info to the terminal'
  spec.description = 'Print detailed code coverage info to the terminal'
  spec.homepage = 'https://github.com/davidrunger/simple_cov-formatter-terminal'
  spec.license = 'MIT'
  required_ruby_version = File.read('.ruby-version').rstrip.sub(/\A(\d+\.\d+)\.\d+\z/, '\1.0')
  spec.required_ruby_version = ">= #{required_ruby_version}"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/davidrunger/simple_cov-formatter-terminal'
  spec.metadata['changelog_uri'] =
    'https://github.com/davidrunger/simple_cov-formatter-terminal/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files =
    Dir.chdir(__dir__) do
      `git ls-files -z`.split("\x0").reject do |f|
        (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git))})
      end
    end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  spec.add_dependency('activesupport', '>= 7.0.4')
  spec.add_dependency('memo_wise', '>= 1.7.0')
  spec.add_dependency('rouge', '>= 4.0.0')
  spec.add_dependency('rspec-core', '>= 3.11.0')
  spec.add_dependency('runger_config', '>= 3.0.0')
  spec.add_dependency('simplecov', '>= 0.21.2')

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
