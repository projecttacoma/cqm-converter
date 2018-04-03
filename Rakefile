require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'cqm/converter'

RSpec::Core::RakeTask.new(:spec)

begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

Dir.glob('lib/tasks/*.rake').each { |r| load r }

task default: :spec
