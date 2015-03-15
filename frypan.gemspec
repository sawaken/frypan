#-*- mode:ruby -*-
# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'frypan/version'

Gem::Specification.new do |spec|
  spec.name          = "frypan"
  spec.version       = Frypan::VERSION
  spec.authors       = ["sawaken"]
  spec.email         = ["sasasawada@gmail.com"]
  spec.summary       = %q{Very small and simple library to do FRP (Functional Reactive Programming) in Ruby in a similar way to Elm.}
  spec.homepage      = "https://github.com/sawaken/tiny_frp2"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
