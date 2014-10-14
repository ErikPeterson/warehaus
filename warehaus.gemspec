# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'warehaus/version'

Gem::Specification.new do |spec|
  spec.name          = "warehaus"
  spec.version       = Warehaus::VERSION
  spec.authors       = ["Erik Sälgström Peterson"]
  spec.email         = ["eriksalgstrom@gmail.com"]
  spec.summary       = "Get files from the 3D warehouse"
  spec.description   = "Fetch KMZ files from the Sketchup 3D Warehouse, and convert them into sensibly named directories and DAE files"
  spec.homepage      = ""
  spec.license       = "GPL"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = ['warehaus']
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"

  spec.add_dependency "httparty", "~> 0.13.1"
  spec.add_dependency "rubyzip", "~> 1.1.6"
end
