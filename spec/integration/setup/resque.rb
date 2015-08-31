require 'chasqui'
Chasqui.config.worker_backend = :resque

require 'resque'
Resque.redis = ENV['REDIS_URL'] if ENV['REDIS_URL']
Resque.redis.namespace = :resque

require './spec/integration/setup/subscribers'
