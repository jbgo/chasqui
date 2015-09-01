class Chasqui::MultiBroker < Chasqui::Broker

  def forward_event
    event = receive or return
    subscribers = subscribers(event)

    redis.multi do
      subscribers.each do |subscriber_id|
        dispatch event, subscriber_id
      end
      redis.rpop(in_progress_queue)
    end

    logger.info "processed event: #{event['event']}, on channel: #{event['channel']}"
  end

  def in_progress_queue
    to_key inbox, 'in_progress'
  end

  def inbox_queue
    to_key inbox
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
    redis.brpoplpush(inbox_queue, in_progress_queue, timeout: config.broker_poll_interval).tap do |event|
      if event.nil?
        logger.debug "reached timeout for broker poll interval: #{config.broker_poll_interval} seconds"
      end
    end
  end

  def dispatch(event, subscriber_id)
    worker_backend, queue_name = subscriber_id.split('/', 2)
    job = { class: "Chasqui::#{Chasqui.subscriber_class_name(queue_name)}", args: [event] }.to_json
    logger.debug "dispatching event to queue: #{queue_name}, backend: #{worker_backend}, job: #{job}"
    case worker_backend
    when 'resque'
      redis.rpush queue_name, job
    when 'sidekiq'
      redis.lpush queue_name, job
    end
  end

  def subscribers(event)
    redis.smembers to_key('subscribers', event['channel'])
  end

  def to_key(*args)
    ([redis_namespace] + args).join(':')
  end

end
