require 'forwardable'
require 'json'
require 'logger'
require 'redis'
require 'redis-namespace'

require "chasqui/version"
require "chasqui/config"
require "chasqui/broker"
require "chasqui/brokers/redis_broker"
require "chasqui/queue_adapter"
require "chasqui/queue_adapter/redis_queue_adapter"
require "chasqui/subscriber"
require "chasqui/subscriptions"
require "chasqui/subscription_builder"
require "chasqui/subscription_builder/resque_subscription_builder"
require "chasqui/subscription_builder/sidekiq_subscription_builder"

# A persistent implementation of the publish-subscribe messaging pattern for
# Resque and Sidekiq workers.
module Chasqui

  class << self
    extend Forwardable
    def_delegators :config, *CONFIG_SETTINGS
    def_delegators :subscriptions, :register, :unregister

    # Yields an object for configuring Chasqui.
    #
    # @example
    #   Chasqui.configure do |config|
    #     config.redis = 'redis://my-redis.example.com:6379'
    #     config.channel_prefix = 'custom.prefix'
    #   end
    #
    # @see Config See Chasqui::Config for a full list of configuration options.
    #
    # @yieldparam config [Config]
    def configure(&block)
      yield config
    end

    # Returns the Chasqui configuration object.
    #
    # @see Config See Chasqui::Config for a full list of configuration options.
    #
    # @return [Config]
    def config
      @config ||= Config.new
    end

    # Publish an event to a channel.
    #
    # @param [String] channel name
    # @param args [Array<#to_json>] an array of JSON serializable objects that
    #   comprise the event's payload.
    def publish(channel, *args)
      redis.lpush inbox_queue, build_event(channel, *args).to_json
    end

    # Returns the mapping of queues and channels to subscriber classes.
    #
    # @return [Subscriptions]
    def subscriptions
      @subscriptions ||= Subscriptions.new build_queue_adapter
    end

    def subscribe(options={})
      builder = subscription_builder_for_backend.new(subscriptions, options)
      builder.instance_eval &Proc.new
    end

    def subscription_builder_for_backend
      case worker_backend
      when :resque
        ResqueSubscriptionBuilder
      when :sidekiq
        SidekiqSubscriptionBuilder
      end
    end

    private

    def build_event(channel, *args)
      opts = extract_job_options!(*args)

      payload = { channel: channel, payload: args }
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

    def build_queue_adapter
      queue_adapter.new
    end
  end
end
