module Chasqui

  # Raised when configured settings prevent Chasqui from working correctly.
  class ConfigurationError < StandardError
  end

  # @visibility private
  CONFIG_SETTINGS = [
    :broker_poll_interval,
    :channel_prefix,
    :default_queue,
    :inbox_queue,
    :logger,
    :queue_adapter,
    :redis,
    :worker_backend
  ]

  # Stores and manages all Chasqui configuration settings.
  class Config < Struct.new(*CONFIG_SETTINGS)

    # @!attribute broker_poll_interval
    #   How long the broker daemon waits for an event before pausing to handle
    #   signals. Default: +3+
    #   @return [Fixnum] seconds

    # @!attribute channel_prefix
    #   A string to prepend to channel names for all published events. This is
    #   useful for namespacing channel names to prevent collisions with other
    #   applications that may choose the same channel name for a different type
    #   of event. Default: +nil+
    #
    #   @example
    #       Chasqui.configure do |c|
    #         c.channel_prefix = 'com.example.app1'
    #       end
    #
    #       # publishes to channel: "com.example.app1.user.signup"
    #       Chasqui.publish 'user.signup', user
    #
    #   @return [String]

    # @!attribute default_queue
    #   The queue to use when a worker class does not define a queue and a
    #   queue option is not supplied to {Chasqui::SubscriptionBuilder#on #on}.
    #   Default: +"chasqui-workers"+
    #   @return [String]

    # @!attribute inbox_queue
    #   The queue that stores published events until they are delivered to
    #   subscriber (worker) queues. Default: "chasqui-inbox"
    #   @return [String]

    # @!attribute logger
    #   The logger to use for the Chasqui broker. Default: +Logger.new(STDOUT)+
    #   @return [Logger]

    # @!attribute [rw] queue_adapter
    #   @api private
    #   The queue adapter to use for binding queues to channels.
    #   @return [Chasqui::QueueAdapter]

    # @!attribute redis
    #   Customize the Redis databse connection Chasqui uses.
    #   Default: +"redis://localhost:6379/0"+
    #   @return [Redis,String,Hash]

    # @!attribute worker_backend
    #   The type of worker that will handle events in class to
    #   {Chasqui.subscribe}. Can be either +resque+ or +sidekiq+. Chasqui will
    #   attempt to auto-detect the +worker_backend+ if either library is
    #   loaded. Default: +nil+
    #   @return [Symbol]

    # @visibility private
    # Default values for all configuration settings.
    Defaults = {
      broker_poll_interval: 3,
      channel_prefix: nil,
      default_queue: 'chasqui-workers',
      inbox_queue: 'chasqui-inbox',
      logger: STDOUT,
      queue_adapter: -> { QueueAdapter::RedisQueueAdapter },
      redis_namespace: 'chasqui',
      worker_backend: nil
    }.freeze

    def default_queue
      self[:default_queue] ||= Defaults.fetch(:default_queue)
    end

    def inbox_queue
      self[:inbox_queue] ||= Defaults.fetch(:inbox_queue)
    end

    def queue_adapter
      self[:queue_adapter] ||= Defaults.fetch(:queue_adapter).call
    end

    def worker_backend
      self[:worker_backend] ||= choose_worker_backend
    end

    def redis
      unless self[:redis]
        self.redis = Redis.new
      end

      self[:redis]
    end

    def redis=(redis_config)
      client = case redis_config
      when Redis
        redis_config
      when String
        Redis.new url: redis_config
      else
        Redis.new redis_config
      end

      self[:redis] = Redis::Namespace.new(Defaults.fetch(:redis_namespace), redis: client)
    end

    def logger
      unless self[:logger]
        self.logger = STDOUT
      end

      self[:logger]
    end

    def logger=(new_logger)
      lg = if new_logger.respond_to? :info
        new_logger
      else
        Logger.new(new_logger).tap do |lg|
          lg.level = Logger::INFO
        end
      end

      lg.progname = 'chasqui'
      self[:logger] = lg
    end

    def broker_poll_interval
      self[:broker_poll_interval] ||= Defaults.fetch(:broker_poll_interval)
    end

    private

    def choose_worker_backend
      if Object.const_defined? :Sidekiq
        :sidekiq
      elsif Object.const_defined? :Resque
        :resque
      end
    end
  end
end
