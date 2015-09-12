require 'forwardable'
require 'json'
require 'logger'
require 'redis'
require 'redis-namespace'

require "chasqui/version"
require "chasqui/config"
require "chasqui/broker"
require "chasqui/multi_broker"
require "chasqui/subscriber"
require "chasqui/subscription"
require "chasqui/workers/worker"
require "chasqui/workers/resque_worker"
require "chasqui/workers/sidekiq_worker"

module Chasqui
  class << self
    extend Forwardable
    def_delegators :config, :redis, :channel, :inbox, :inbox_queue, :logger

    def configure(&block)
      @config ||= Config.new
      yield @config
    end

    def config
      @config ||= Config.new
    end

    def publish(event, *args)
      redis.lpush inbox_queue, build_payload(event, *args).to_json
    end

    def subscribe(options={}, &block)
      queue = options.fetch :queue
      channel = options.fetch :channel

      create_subscription(queue, channel).tap do |subscription|
        subscription.subscriber.evaluate(&block) if block_given?
        redis.sadd subscription_key(channel), subscription.subscription_id
      end
    end

    def unsubscribe(options={}, &block)
      queue = options.fetch :queue
      channel = options.fetch :channel

      subscription = subscriptions[queue.to_s]

      if subscription
        redis.srem subscription_key(channel), subscription.subscription_id
        subscription.subscription_id
      end
    end

    def subscription(queue)
      subscriptions[queue.to_s]
    end

    def subscriber_class_name(queue)
      queue_name_constant = queue.split(':').last.gsub(/[^\w]/, '_')
      "Subscriber__#{queue_name_constant}".to_sym
    end

    private

    def subscription_key(channel)
      "subscriptions:#{channel}"
    end

    def create_subscription(queue, channel)
      subscriptions[queue.to_s] ||= Subscription.new queue, channel
    end

    def subscriptions
      @subscriptions ||= {}
    end

    def build_payload(event, *args)
      opts = extract_job_options!(*args)

      payload = { event: event, channel: channel, data: args }
      payload[:retry] = opts[:retry] || opts['retry'] if opts
      payload[:created_at] = Time.now.to_f.to_s

      payload
    end

    def extract_job_options!(*args)
      if args.last.kind_of?(Hash)
        args.last.delete(:job_options)
      end
    end
  end
end
