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

      register_subscriber(queue, channel).tap do |sub|
        sub.evaluate(&block) if block_given?
        worker = create_worker(sub)
        redis.sadd "subscribers:#{channel}", subscriber_id(worker, queue)
      end
    end

    def subscriber(queue)
      subscribers[queue.to_s]
    end

    def subscriber_class_name(queue)
      queue_name_constant = queue.split(':').last.gsub(/[^\w]/, '_')
      "Subscriber__#{queue_name_constant}".to_sym
    end

    def create_worker(subscriber)
      case config.worker_backend
      when :resque
        Chasqui::ResqueWorker.create subscriber
      when :sidekiq
        Chasqui::SidekiqWorker.create subscriber
      else
        raise ConfigurationError.new(
          "Please choose a supported worker_backend. Choices: #{supported_worker_backends}")
      end
    end

    private

    def subscriber_id(worker, queue)
      queue_name = [worker.namespace, 'queue', queue].compact.join(':')
      "#{config.worker_backend}/#{queue_name}"
    end

    def register_subscriber(queue, channel)
      subscribers[queue.to_s] ||= Subscriber.new queue, channel
    end

    def subscribers
      @subscribers ||= {}
    end

    SUPPORTED_WORKER_BACKENDS = [:resque, :sidekiq].freeze

    def supported_worker_backends
      SUPPORTED_WORKER_BACKENDS.join(', ')
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
