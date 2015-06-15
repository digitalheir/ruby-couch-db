# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'couch/db/version'

Gem::Specification.new do |spec|
  spec.name = 'couch-db'
  spec.version = Couch::DB::VERSION
  spec.authors = ['Maarten Trompper']
  spec.email = ['maartentrompper@gmail.com']

  spec.required_ruby_version = '>= 2'

  spec.summary = %q{Interface with a CouchDB database. Focuses on bulk requests.}
  # spec.description   = %q{Write a longer description or delete this line.}
  spec.homepage = 'https://github.com/digitalheir/couch-request'
  spec.license = 'MIT'

  # # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # # delete this section to allow pushing this gem to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = "http://mygemserver.com"
  # else
  #   raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  # end

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 2.4'
  spec.add_development_dependency 'codeclimate-test-reporter'


  spec.add_runtime_dependency 'json', '~> 1'
end
