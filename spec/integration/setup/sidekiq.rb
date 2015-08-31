require 'chasqui'
require 'sidekiq'

Chasqui.config.worker_backend = :sidekiq

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'], namespace: ENV['REDIS_NAMESPACE'] }
end

require './spec/integration/setup/subscribers'
