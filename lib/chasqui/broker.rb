class Chasqui::Broker
  attr_reader :config

  extend Forwardable
  def_delegators :@config, :redis, :inbox

  ShutdownSignals = %w(INT QUIT ABRT TERM).freeze

  # The broker uses blocking redis commands, so we create a new redis connection
  # for the broker, to prevent unsuspecting clients from blocking forever.
  def initialize
    @config = Chasqui.config.dup
    @config.redis = Redis.new @config.redis.client.options
  end

  def start
    ShutdownSignals.each do |signal|
      trap(signal) { exit 0 }
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
    payload ||= redis.brpoplpush(inbox, in_progress_queue, timeout: 0)

    event = JSON.parse payload
    queues = redis.smembers "queues:#{event['namespace']}"

    redis.multi do
      queues.each { |queue| redis.rpush queue, payload }
      redis.rpop(in_progress_queue)
    end
  end

  def in_progress_queue
    "#{inbox}:in_progress"
  end

end
