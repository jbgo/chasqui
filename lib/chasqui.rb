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
require "chasqui/subscribers/inline_subscriber"
require "chasqui/subscriptions"
require "chasqui/subscriptions/redis_subscriptions"
require "chasqui/workers/worker"
require "chasqui/workers/resque_worker"
require "chasqui/workers/sidekiq_worker"

module Chasqui

  class ConfigurationError < StandardError; end

  class << self
    extend Forwardable
    def_delegators :config, *CONFIG_SETTINGS
    def_delegators :subscriptions, :register, :unregister

    def configure(&block)
      yield config
    end

    def config
      @config ||= Config.new
    end

    def publish(channel, *args)
      redis.lpush inbox_queue, build_event(channel, *args).to_json
    end

    def subscribe(channel, queue=Chasqui.default_queue, &block)
      subscriber = InlineSubscriber.create channel, queue, &block
      register subscriber
    end

      # create_subscription(queue, channel).tap do |subscription|
      #   subscription.subscriber.evaluate(&block) if block_given?
      #   redis.sadd subscription_key(channel), subscription.subscription_id
      # end
    # end

    def unsubscribe(channel, options={}, &block)
      queue = options.fetch :queue

      subscriptions.
        find(channel, queue).
        select { |s| s.kind_of?(InlineSubscriber) }.
        each { |s| subscriptions.unregister s }

      # if subscription
      #   redis.srem subscription_key(channel), subscription.subscription_id
      #   subscription.subscription_id
      # end
    end

    # def subscription(queue)
    #   subscriptions[queue.to_s]
    # end

    # def subscription_key(channel)
    #   "subscriptions:#{channel}"
    # end

    def subscriptions
      @subscriptions ||= Subscriptions.new
    end

    private

    def build_event(channel, *args)
      opts = extract_job_options!(*args)

      payload = { channel: channel, data: args }
      payload[:retry] = fetch_option(opts, :retry, true) || false
      payload[:created_at] = Time.now.to_f.to_s

      payload
    end

    def extract_job_options!(*args)
      opts = args.last.delete(:job_options) if args.last.kind_of?(Hash)
      opts ||= {}
    end

    def fetch_option(opts, key, default=nil)
      opts.fetch key.to_sym, opts.fetch(key.to_s, default)
    end
  end
end
