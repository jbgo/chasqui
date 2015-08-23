module Chasqui

  Defaults = {
    inbox_queue: 'inbox',
    redis_namespace: 'chasqui',
    publish_channel: '__default',
    broker_poll_interval: 3
  }.freeze

  class ConfigurationError < StandardError
  end

  CONFIG_SETTINGS = %i(
    broker_poll_interval
    channel
    inbox_queue
    logger
    redis
    worker_backend
  )

  class Config < Struct.new(*CONFIG_SETTINGS)
    def channel
      self[:channel] ||= Defaults.fetch(:publish_channel)
    end

    def inbox_queue
      self[:inbox_queue] ||= Defaults.fetch(:inbox_queue)
    end
    alias inbox inbox_queue

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
