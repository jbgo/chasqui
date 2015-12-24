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

    # Yields an object for configuring Chasqui.
    #
    # @example
    #   Chasqui.configure do |c|
    #     c.redis = 'redis://my-redis.example.com:6379'
    #     ...
    #   end
    #
    # @see Config See Chasqui::Config for a full list of configuration options.
    #
    # @yieldparam config [Config]
    def configure(&block)
      yield config
    end

    # @visibility private
    #
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
    # @param channel [String] the channel name
    # @param args [Array<#to_json>] an array of JSON serializable objects that
    #   comprise the event's payload.
    def publish(channel, *args)
      redis.lpush inbox_queue, build_event(channel, *args).to_json
    end

    # Subscribe workers to channels.
    #
    #     Chasqui.subscribe(queue: 'high-priority') do
    #       on 'channel1', Worker1
    #       on 'channel2', Worker2
    #       on 'channel3', ->(event) { ... }, queue: 'low-priority'
    #       ...
    #     end
    #
    # The +.subscribe+ method creates a context for registering workers to
    # receive events for specified channels. Within a subscribe block you make
    # calls to the {SubscriptionBuilder#on #on} method to create subscriptions.
    #
    # {SubscriptionBuilder#on #on} expects a channel name as the first argument
    # and either a Resque/Sidekiq worker as the second argument or a callable
    # object, such as a proc, lambda, or any object that responds to +#call+.
    #
    # @see SubscriptionBuilder#on
    #
    # @param [Hash] options default options for calls to +#on+. The defaults
    #   will be overriden by options supplied to the +#on+ method directly.
    #   See {Chasqui::SubscriptionBuilder#on} for available options.
    def subscribe(options={})
      builder = SubscriptionBuilder.builder(subscriptions, options)
      builder.instance_eval &Proc.new
    end

    # @visibility private
    #
    # Returns the registered subscriptions.
    #
    # @return [Subscriptions]
    def subscriptions
      @subscriptions ||= Subscriptions.new build_queue_adapter
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
