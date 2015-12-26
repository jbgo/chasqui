module Chasqui
  # A namespace for defining dynamically generated worker classes for callable
  # objects.
  module Workers
  end

  # Provides the context used in {Chasqui.subscribe} to bind workers to
  # channels via the {#on} method.
  class SubscriptionBuilder
    # The collection of currently registered subscriptions.
    # @return [Chasqui::Subscriptions]
    attr_reader :subscriptions

    # Default options for calls to {#on}.
    # @return [Hash]
    attr_reader :default_options

    # @visibility private
    # You should not instantiate this class directly. Instead use the
    # {Chasqui.subscribe} method to create a subscription builder context.
    def initialize(subscriptions, options={})
      @subscriptions = subscriptions
      @default_options = options
    end

    # Bind a worker to a channel.
    #
    # The broker will place jobs on the worker's queue for each event published
    # to the given channel.
    #
    # @param channel [String] the channel name
    # @param worker_or_proc [#perform,.perform,#call] a Sidekiq Worker
    #   class, Resque worker class, or proc to handle events published to
    #   channel. If a proc is used as a worker, +#on+ will define a new worker
    #   class that delegates +#perform+ to +proc#call+.
    # @param options [Hash]
    #
    # @option options [String] :queue the worker queue.
    #   When given, this option will override the queue defined by the worker
    #   class. This option is recommended when using a proc as a worker.
    # @option options [String] :queue_prefix prefix for queue.
    #   When supplied, the value of this option is prepended to the queue name.
    #   Use this option to namespace your queues in order to prevent collisions
    #   with queues from other applicaitons sharing the same Redis database.
    def on(channel, worker_or_proc, options={})
      options = default_options.merge(options)
      worker = build_worker(channel, worker_or_proc, options)

      queue = full_queue_name(worker, options)
      set_queue_name(worker, queue)
      
      subscriptions.register Chasqui::Subscriber.new(channel, queue, worker)
    end

    # @visibility private
    # Instantiate a new subscription builder suitable for the configured
    # {Chasqui.worker_backend worker_backend}.
    def self.builder(subscriptions, options={})
      builder_for_backend.new subscriptions, options
    end

    protected

    def get_queue_name(worker)
      raise NotImplementedError
    end

    def set_queue_name(worker, queue)
      raise NotImplementedError
    end

    def define_worker_class(channel, callable, options)
      raise NotImplementedError
    end

    def redefine_perform_method(worker, &block)
      raise NotImplementedError
    end

    private

    def self.builder_for_backend
      case Chasqui.worker_backend
      when :resque
        ResqueSubscriptionBuilder
      when :sidekiq
        SidekiqSubscriptionBuilder
      else
        msg = <<-ERR.gsub(/^ {8}/, '')
        No worker backend configured.

            # To configure a worker backend:
            Chasqui.config do |c|
              c.worker_backend = :resque # or :sidekiq
            end
        ERR
        raise Chasqui::ConfigurationError.new msg
      end
    end

    def full_queue_name(worker, options={})
      queue = options.fetch :queue, get_queue_name(worker)
      prefix = options[:queue_prefix]

      prefix ? "#{prefix}:#{queue}" : queue
    end

    def build_worker(channel, worker_or_proc, options={})
      worker = worker_or_proc

      if worker.respond_to? :call
        worker = define_worker_class(channel, worker_or_proc, options)
        Chasqui::Workers.const_set worker_class_name(channel), worker
      end

      redefine_perform_method(worker) do |klass|
        klass.send :define_method, :perform_with_event do |event|
          perform_without_event event, *event['payload']
        end

        klass.send :alias_method, :perform_without_event, :perform
        klass.send :alias_method, :perform, :perform_with_event
      end

      worker
    end

    def worker_class_name(channel)
      segments = channel.split(/[^\w]/).map(&:downcase)
      name = segments.each { |w| w[0] = w[0].upcase }.join

      "#{name}Worker".freeze
    end
  end
end
