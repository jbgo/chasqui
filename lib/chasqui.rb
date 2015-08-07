require 'ostruct'
require 'json'
require "chasqui/version"
require 'redis'
require 'redis-namespace'

module Chasqui

  Defaults = {
    publish_queue: 'inbox',
    redis_namespace: 'chasqui'
  }.freeze

  class Config < Struct.new :namespace, :redis
    def redis=(redis_config)
      client = redis_config.kind_of?(Redis) ? redis_config : Redis.new(redis_config)
      self[:redis] = Redis::Namespace.new(Defaults[:redis_namespace], redis: client)
    end
  end

  module ClassMethods
    def namespace
      config.namespace
    end

    def redis
      unless config.redis
        config.redis = Redis.new
      end

      config.redis
    end

    def publish_queue
      Defaults[:publish_queue]
    end

    def configure(&block)
      @config ||= Config.new
      yield @config
    end

    def config
      @config ||= Config.new
    end

    def publish(event, *args)
      name = namespace ? "#{namespace}.#{event}" : event
      redis.rpush publish_queue, { name: name, data: args }.to_json
    end
  end

end

Chasqui.extend Chasqui::ClassMethods
