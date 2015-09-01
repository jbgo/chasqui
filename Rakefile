require "bundler/gem_tasks"
require "rspec/core/rake_task"

require 'resque/tasks'
task 'resque:setup' => :resque_integration_environment

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :resque_integration_environment do
  require './spec/integration/setup/resque'
end
