def log_event subscriber, payload
  Chasqui.redis.rpush "#{subscriber.class.queue}:event_log", subscriber.event.to_json
end

class UserSignupSubscriber < Chasqui::Subscriber
  channel 'user.signup'
  queue 'app1'

  def perform(payload)
    log_event self, payload
  end
end

class AccountSubscriber < Chasqui::Subscriber
  channel 'account.credit', 'account.debit'
  queue 'app2'

  def perform(payload)
    log_event self, payload
  end
end

class UserCancelSubscriber < Chasqui::Subscriber
  channel 'user.cancel'
  queue 'app2'

  def perform(payload)
    log_event self, payload
  end
end

Chasqui.autoregister!
