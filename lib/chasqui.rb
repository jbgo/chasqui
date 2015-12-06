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
require "chasqui/queue_adapters/redis_queue_adapter"
require "chasqui/subscriber"
require "chasqui/subscriptions"
require "chasqui/worker"

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
