module Chasqui
  module QueueAdapters
    class Redis
      extend Forwardable
      def_delegators :Chasqui, :redis

      def bind(subscriber)
        redis.sadd key(subscriber), queue_description(subscriber)
      end

      def unbind(subscriber)
        redis.srem key(subscriber), queue_description(subscriber)
      end

      private

      def key(subscriber)
        "subscriptions:#{subscriber.channel}"
      end

      def subscriptions_key(subscriber)
        "subscribers:#{subscriber.channel}"
      end

      def queue_description(subscriber)
        queue_name = [worker_namespace, 'queue', subscriber.queue].compact.join(':')
        "#{worker_backend}/#{subscriber.class}/#{queue_name}"
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
