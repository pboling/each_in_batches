# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'each_in_batches/version'

Gem::Specification.new do |spec|
  spec.name          = "each_in_batches"
  spec.version       = EachInBatches::VERSION
  spec.authors       = ["Peter Boling"]
  spec.email         = ["peter.boling@gmail.com"]

  spec.summary       = "Batch Processing of Records with Blocks in Rails"
  spec.description   = "Batch Processing of Records with Blocks in Rails"
  spec.homepage      = "https://github.com/pboling/each_in_batches"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 3.2", "< 5.0"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.2"
end
