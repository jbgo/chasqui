def log_event subscriber, payload
  event_info = { channel: subscriber.channel, payload: payload }.to_json
  subscriber.redis.rpush "#{subscriber.queue}:event_log", event_info
end

class UserSignupSubscriber < Chasqui::Subscriber
  channel 'user.signup'

  def perform(payload)
    log_event self, payload
  end
end

class AccountSubscriber < Chasqui::Subscriber
  channel 'account.credit', 'account.debit'

  def perform(payload)
    log_event self, payload
  end
end

class UserCancelSubscriber < Chasqui::Subscriber
  channel 'user.cancel'

  def perform(payload)
    log_event self, payload
  end
end

Chasqui.autoregister!
