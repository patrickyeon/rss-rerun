# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rerun/version'

Gem::Specification.new do |spec|
  spec.name          = "rerun"
  spec.version       = Rerun::VERSION
  spec.authors       = ["Patrick Yeon"]
  spec.email         = ["patrickyeon@gmail.com"]
  spec.description   = 'Description goes here'
  spec.summary       = 'Summary goes here'
  spec.homepage      = 'https://github.com/patrickyeon/rss-rerun'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.0'
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_dependency 'sinatra'
  spec.add_dependency 'nokogiri'
end
