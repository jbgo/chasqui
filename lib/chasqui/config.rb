module Chasqui

  Defaults = {
    default_queue: 'chasqui-subscribers',
    inbox_queue: 'inbox',
    redis_namespace: 'chasqui',
    broker_poll_interval: 3,
    queue_adapter: -> { QueueAdapters::Redis }
  }.freeze

  class ConfigurationError < StandardError
  end

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

  class Config < Struct.new(*CONFIG_SETTINGS)
    def default_queue
      self[:default_queue] ||= Defaults.fetch(:default_queue)
    end

    def inbox_queue
      self[:inbox_queue] ||= Defaults.fetch(:inbox_queue)
    end

    def queue_adapter
      self[:queue_adapter] ||= Defaults.fetch(:queue_adapter).call
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
  end
end
