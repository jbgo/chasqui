class Chasqui::Broker
  attr_reader :config

  extend Forwardable
  def_delegators :@config, :redis, :inbox, :logger

  ShutdownSignals = %w(INT QUIT ABRT TERM).freeze

  # The broker uses blocking redis commands, so we create a new redis connection
  # for the broker, to prevent unsuspecting clients from blocking forever.
  def initialize
    @config = Chasqui.config.dup
    @config.redis = Redis.new @config.redis.client.options
    logger.info "configured to fetch events from #{inbox} on #{redis.inspect}"
  end

  def start
    logger.info "waiting for events"

    ShutdownSignals.each do |signal|
      trap(signal) { exit 0  }
    end

    loop { forward_event }
  end

  def forward_event
    raise NotImplementedError.new "please define #forward_event in a subclass of #{self.class.name}"
  end

end

class Chasqui::MultiBroker < Chasqui::Broker

  def forward_event
    payload = redis.lrange(in_progress_queue, -1, -1).first
    logger.warn "detected failed event delivery, attempting recovery"

    payload ||= redis.brpoplpush(inbox, in_progress_queue, timeout: 0)

    event = JSON.parse payload
    qualified_event_name = "#{event['namespace']}::#{event['name']}"
    logger.debug "received event: #{qualified_event_name}, payload: #{payload}"

    queues = redis.smembers "queues:#{event['namespace']}"
    logger.debug "subscriber queues: #{queues.join(', ')}"

    redis.multi do
      queues.each { |queue| redis.rpush queue, payload }
      redis.rpop(in_progress_queue)
    end

    logger.debug "processed event: #{qualified_event_name}"
  end

  def in_progress_queue
    "#{inbox}:in_progress"
  end

end
