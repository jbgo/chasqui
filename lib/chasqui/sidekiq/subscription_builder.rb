module Chasqui
  module Workers
  end

  module Sidekiq
    class SubscriptionBuilder
      attr_reader :subscriptions

      def initialize(subscriptions)
        @subscriptions = subscriptions
      end

      def on(channel, worker_or_callable, options={})
        worker = build_worker(channel, worker_or_callable, options)

        subscriptions.register channel, worker, queue_name(worker, options)
      end

      private

      def queue_name(worker, options={})
        queue = options.fetch :queue, worker.sidekiq_options['queue']

        prefix = options[:queue_name_prefix]
        queue = "#{prefix}:#{queue}" if prefix

        worker.sidekiq_options queue: queue

        queue
      end

      def build_worker(channel, worker_or_callable, options={})
        if worker_or_callable.respond_to? :call
          define_worker_class(channel, worker_or_callable, options)
        else
          worker_or_callable
        end
      end

      def define_worker_class(channel, callable, options)
        worker =
          Class.new do
            include ::Sidekiq::Worker
            define_method :perform, callable
          end

        Chasqui::Workers.const_set worker_class_name(channel), worker
      end

      def worker_class_name(channel)
        segments = channel.split(/[^\w]/).map(&:downcase)
        name = segments.each { |w| w[0] = w[0].upcase }.join

        "#{name}Worker".freeze
      end
    end
  end
end
