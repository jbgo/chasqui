def log_event subscriber, args
  event = subscriber.current_event
  payload = { event: event['event'], data: args }.to_json
  subscriber.redis.rpush "#{subscriber.queue}:event_log", payload
end

Chasqui.subscribe queue: 'app1', channel: 'integration' do
  on('user.signup') { |*args| log_event self, args }
end

Chasqui.subscribe queue: 'app2', channel: 'integration' do
  on('account.*')   { |*args| log_event self, args }
  on('user.cancel') { |*args| log_event self, args }
end
