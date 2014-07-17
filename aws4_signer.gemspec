# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aws4_signer/version'

Gem::Specification.new do |spec|
  spec.name          = "aws4_signer"
  spec.version       = Aws4Signer::VERSION
  spec.authors       = ["Shota Fukumori (sora_h)"]
  spec.email         = ["her@sorah.jp"]
  spec.summary       = %q{Simple signer module implements AWS4 signature}
  spec.description   = nil
  spec.homepage      = "https://github.com/sorah/aws4_signer"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", '~> 5.4.0'
  spec.add_development_dependency 'minitest-reporters', '~> 1.0.5'
end
