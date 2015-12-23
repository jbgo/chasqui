require 'chasqui'
require 'sidekiq'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'], namespace: ENV['REDIS_NAMESPACE'] }
end

def log_event(worker, event, *args)
  queue = worker.sidekiq_options_hash['queue']
  event['worker_args'] = args

  Chasqui.redis.rpush "#{queue}:event_log", event.to_json
end

class UserSignupWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'app1'

  def perform(event, *args)
    log_event self, event, *args
  end
end

class TransactionWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'app2'

  def perform(event, *args)
    log_event self, event, *args
  end
end

class UserCancelWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'app2'

  def perform(event, *args)
    log_event self, event, *args
  end
end

Chasqui.subscribe do
  on 'user.signup', UserSignupWorker
  on 'user.cancel', UserCancelWorker
  on 'account.credit', TransactionWorker
  on 'account.debit', TransactionWorker
end
