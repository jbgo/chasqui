def log_event subscriber, payload
  Chasqui.redis.rpush "#{subscriber.class.queue}:event_log", subscriber.event.to_json
end

class UserSignupSubscriber
  include Chasqui::Subscriber
  subscribe channel: 'user.signup', queue: 'app1'

  def perform(*args)
    log_event self, args
  end
end

class AccountSubscriber
  include Chasqui::Subscriber
  subscribe channel: ['account.credit', 'account.debit'], queue: 'app2'

  def perform(*args)
    log_event self, args
  end
end

class UserCancelSubscriber
  include Chasqui::Subscriber
  subscribe channel: 'user.cancel', queue: 'app2'

  def perform(*args)
    log_event self, args
  end
end
