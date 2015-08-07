require 'json'
require 'redis'
require 'redis-namespace'

require "chasqui/version"
require "chasqui/subscriber"

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

    def subscribe(queue:, namespace:, &block)
      register_subscriber(queue, namespace).tap do |sub|
        sub.evaluate(&block) if block_given?
        redis.sadd "queues:#{namespace}", queue
      end
    end

    def subscriber(queue)
      subscribers[queue.to_s]
    end

    private

    def register_subscriber(queue, namespace)
      subscribers[queue.to_s] ||= Subscriber.new
    end

    def subscribers
      @subscribers ||= {}
    end
  end

end

Chasqui.extend Chasqui::ClassMethods
