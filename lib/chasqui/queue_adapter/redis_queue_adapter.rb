module Chasqui
  module QueueAdapter
    class RedisQueueAdapter
      extend Forwardable
      def_delegators :Chasqui, :redis

      def bind(subscriber)
        redis.sadd key(subscriber.channel), queue_description(subscriber)
        worker_redis.sadd 'queues', subscriber.queue
      end

      def unbind(subscriber)
        redis.srem key(subscriber.channel), queue_description(subscriber)
      end

      private

      def key(channel)
        "subscriptions:#{channel}"
      end

      def queue_description(subscriber)
        queue_name = [worker_namespace, 'queue', subscriber.queue].compact.join(':')
        "#{worker_backend}/#{subscriber.worker.name}/#{queue_name}"
      end

      def worker_redis
        case worker_backend
        when :resque
          Resque.redis
        when :sidekiq
          ::Sidekiq.redis { |r| r }
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
