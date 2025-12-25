# frozen_string_literal: true

require_relative "lib/caotral/version"

Gem::Specification.new do |spec|
  spec.name = "caotral"
  spec.version = Caotral::VERSION
  spec.authors = ["MATSUMOTO, Katsuyoshi"]
  spec.email = ["github@katsyoshi.org"]

  spec.summary = "Caotral is the ruby native compiler."
  spec.description = "Caotral is the caotral."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.homepage = "https://github.com/katsyoshi/caotral"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
