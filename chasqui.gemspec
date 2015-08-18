# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chasqui/version'

Gem::Specification.new do |spec|
  spec.name          = "chasqui"
  spec.version       = Chasqui::VERSION
  spec.authors       = ["Jordan Bach"]
  spec.email         = ["jordan@opensolitude.com"]
  spec.summary       = %q{Chasqui is a simple, lightweight, persistent implementation of the publish-subscribe (pub/sub) messaging pattern for service oriented architectures.}
  spec.homepage      = "https://github.com/jbgo/chasqui"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "redis"
  spec.add_dependency "redis-namespace"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "sidekiq"
end
