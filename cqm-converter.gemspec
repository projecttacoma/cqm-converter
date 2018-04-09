lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'cqm-converter'
  spec.version       = '0.1.0'
  spec.authors       = ['aholmes@mitre.org']
  spec.email         = ['aholmes@mitre.org']

  spec.summary       = 'HDS <=> QDM Model Converter'
  spec.homepage      = 'https://github.com/projecttacoma/cqm-converter'
  spec.license       = 'Apache-2.0'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'activesupport'
  spec.add_development_dependency 'bundler', '~> 1.15'
  spec.add_development_dependency 'byebug', '~> 10.0.0'
  spec.add_runtime_dependency 'coffee-script'
  spec.add_runtime_dependency 'cql_qdm_patientapi'
  spec.add_runtime_dependency 'execjs'
  spec.add_runtime_dependency 'health-data-standards', '~> 4.0.0'
  spec.add_runtime_dependency 'momentjs-rails'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.54.0'
  spec.add_runtime_dependency 'sprockets'
end
