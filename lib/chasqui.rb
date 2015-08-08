require 'json'
require 'redis'
require 'redis-namespace'

require "chasqui/version"
require "chasqui/subscriber"
require "chasqui/broker"

module Chasqui

  Defaults = {
    inbox_queue: 'inbox',
    redis_namespace: 'chasqui',
    publish_namespace: '__default'
  }.freeze

  class Config < Struct.new :namespace, :redis
    def namespace
      self[:namespace] ||= Defaults.fetch(:publish_namespace)
    end

    def redis
      unless self[:redis]
        self.redis = Redis.new
      end

      self[:redis]
    end

    def redis=(redis_config)
      client = redis_config.kind_of?(Redis) ? redis_config : Redis.new(redis_config)
      self[:redis] = Redis::Namespace.new(Defaults.fetch(:redis_namespace), redis: client)
    end

    def inbox_queue
      Defaults.fetch(:inbox_queue)
    end
    alias inbox inbox_queue
  end

  module ClassMethods
    extend Forwardable
    def_delegators :config, :redis, :namespace, :inbox, :inbox_queue

    def configure(&block)
      @config ||= Config.new
      yield @config
    end

    def config
      @config ||= Config.new
    end

    def publish(event, *args)
      payload = { event: event, namespace: namespace, data: args }
      redis.lpush inbox_queue, payload.to_json
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
