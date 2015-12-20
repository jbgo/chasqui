require 'chasqui'
require 'resque'

Resque.redis = ENV['REDIS_URL'] if ENV['REDIS_URL']
Resque.redis.namespace = :resque

def log_event(worker, event, *args)
  queue = worker.sidekiq_options_hash['queue']
  event['worker_args'] = args

  Chasqui.redis.rpush "#{queue}:event_log", event.to_json
end

class UserSignupWorker
  @queue = 'app1'

  def perform(event, *args)
    log_event self, event, args
  end
end

class AccountWorker
  @queue = 'app2'

  def perform(event, *args)
    log_event self, event, args
  end
end

class UserCancelWorker
  @queue = 'app2'

  def perform(event, *args)
    log_event self, event, args
  end
end

Chasqui.subscribe do
  on 'user.signup', UserSignupWorker
  on 'user.cancel', UserCancelWorker
  on 'account.credit', TransactionWorker
  on 'account.debit', TransactionWorker
end
