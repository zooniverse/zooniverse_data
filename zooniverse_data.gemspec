# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'zooniverse_data/version'

Gem::Specification.new do |spec|
  spec.name          = 'zooniverse_data'
  spec.version       = ZooniverseData::VERSION
  spec.authors       = ['Michael Parrish']
  spec.email         = ['michael@zooniverse.org']
  spec.summary       = 'Zooniverse data library'
  spec.homepage      = 'https://github.com/zooniverse/zooniverse_data'
  spec.license       = 'MIT'
  
  ignored_paths      = %w(manifests data).join '|'
  spec.files         = `git ls-files -z`.split("\x0").reject{ |f| f =~ /^(#{ ignored_paths })/ }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  
  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake', '~> 10.1.0'
  spec.add_development_dependency 'bson', '1.9.2'
  spec.add_development_dependency 'bson_ext', '1.9.2'
  spec.add_runtime_dependency 'fastimage', '1.6.0'
  spec.add_runtime_dependency 'aws-sdk', '~> 2.3.18'
  spec.required_ruby_version = '>= 2.0.0'
end
