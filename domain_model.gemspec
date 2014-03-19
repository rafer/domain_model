# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'domain_model/version'

Gem::Specification.new do |spec|
  spec.name          = "domain_model"
  spec.version       = DomainModel::VERSION
  spec.authors       = ["Rafer Hazen"]
  spec.email         = ["rafer@ralua.com"]
  spec.summary       = %q{Minimal framework for definition of (optionally) type-aware domain models}
  spec.description   = spec.summary
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.14"
end
