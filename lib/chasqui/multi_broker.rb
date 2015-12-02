require 'securerandom'

class Chasqui::MultiBroker < Chasqui::Broker

  def forward_event
    event = receive or return
    subscriptions = subscriptions_for(event)

    redis.multi do
      subscriptions.each do |subscription_id|
        dispatch event, subscription_id
      end
      redis.rpop(in_progress_queue)
    end

    logger.info "processed event: #{event['event']}, on channel: #{event['channel']}"
  end

  def in_progress_queue
    with_namespace inbox_queue, 'in_progress'
  end

  def namespaced_inbox_queue
    with_namespace inbox_queue
  end

  def build_job(queue, event)
    {
      class: "Chasqui::#{Chasqui.subscriber_class_name(queue)}",
      args: [event],
      queue: 'my-queue',
      jid: SecureRandom.hex(12),
      created_at: (event['created_at'] || Time.now).to_f,
      enqueued_at: Time.now.to_f,
      retry: event['retry']
    }.to_json
  end

  private

  def receive
    event = retry_failed_event || dequeue

    if event
      JSON.parse(event).tap do |e|
        logger.debug "received event: #{e['event']}, on channel: #{e['channel']}"
      end
    end
  end

  def retry_failed_event
    redis.lrange(in_progress_queue, -1, -1).first.tap do |event|
      unless event.nil?
        logger.warn "detected failed event delivery, attempting recovery"
      end
    end
  end

  def dequeue
    redis.brpoplpush(namespaced_inbox_queue, in_progress_queue, timeout: config.broker_poll_interval).tap do |event|
      if event.nil?
        logger.debug "reached timeout for broker poll interval: #{config.broker_poll_interval} seconds"
      end
    end
  end

  def dispatch(event, subscription_id)
    backend, queue = subscription_id.split('/', 2)
    job = build_job queue, event

    logger.debug "dispatching event queue=#{queue} backend=#{backend} job=#{job}"

    case backend
    when 'resque'
      redis.rpush queue, job
    when 'sidekiq'
      redis.lpush queue, job
    end
  end

  def subscriptions_for(event)
    subscription_key = Chasqui.subscription_key event['channel']
    redis.smembers with_namespace(subscription_key)
  end

  def with_namespace(*args)
    ([redis_namespace] + args).join(':')
  end

end
