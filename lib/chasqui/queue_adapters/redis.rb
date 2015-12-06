module Chasqui
  module QueueAdapters
    class Redis
      extend Forwardable
      def_delegators :Chasqui, :redis

      def bind(subscriber)
        subscriber.channels.each do |channel|
          redis.sadd key(channel), queue_description(subscriber)
        end
      end

      def unbind(subscriber)
        subscriber.channels.each do |channel|
          redis.srem key(channel), queue_description(subscriber)
        end
      end

      private

      def key(channel)
        "subscriptions:#{channel}"
      end

      def queue_description(subscriber)
        queue_name = [worker_namespace, 'queue', subscriber.queue].compact.join(':')
        "#{worker_backend}/Chasqui::Workers::#{subscriber.name}/#{queue_name}"
      end

      def worker_redis
        case worker_backend
        when :resque
          Resque.redis
        when :sidekiq
          Sidekiq.redis { |r| r }
        end
      end

      def worker_namespace
        worker_redis.namespace if worker_redis.respond_to? :namespace
      end

      def worker_backend
        Chasqui.config.worker_backend
      end
    end
  end
end
