module Chasqui
  class SidekiqSubscriptionBuilder < SubscriptionBuilder
    def get_queue_name(worker)
      worker.sidekiq_options['queue']
    end

    def set_queue_name(worker, queue)
      worker.sidekiq_options queue: queue
    end

    def define_worker_class(channel, callable, options)
      Class.new do
        include ::Sidekiq::Worker
        sidekiq_options queue: Chasqui.default_queue
        define_method :perform, callable
      end
    end
  end
end
