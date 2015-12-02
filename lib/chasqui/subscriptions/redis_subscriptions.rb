module Chasqui
  class RedisSubscriptions < Subscriptions
    def bind(subscriber)
      key = subscriptions_key subscriber
      queue_id = queue_id subscriber
      Chasqui.redis.sadd key, queue_id
    end

    private

    def subscriptions_key(subscriber)
      "subscribers:#{subscriber.channel}"
    end

    def queue_id(subscriber)
      queue_name = [namespace, 'queue', subscriber.queue].join(':')
      "#{backend}/#{queue_name}"
    end

    def namespace
      case backend
      when :resque
        Resque.redis.namespace
      when :sidekiq
        Sidekiq.redis { |r| r.namespace if r.respond_to?(:namespace) }
      end
    end

    def backend
      Chasqui.worker_backend or raise ConfigurationError.new(
        'you must configure the :worker_backend')
    end
  end
end
