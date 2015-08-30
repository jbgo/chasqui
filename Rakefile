require "bundler/gem_tasks"
require "rspec/core/rake_task"

require 'resque/tasks'
task 'resque:setup' => :environment

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :environment do
  $LOAD_PATH.unshift './lib'
  require 'bundler/setup'
  require 'chasqui'

  if ENV['CHASQUI_ENV'] == 'test'
    require './spec/integration/subscribers'
  end

  require 'resque'
  Resque.redis = ENV['REDIS_URL'] if ENV['REDIS_URL']
  Resque.redis.namespace = :resque
end
