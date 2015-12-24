module Chasqui
  class SidekiqSubscriptionBuilder < SubscriptionBuilder
    protected

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

    def redefine_perform_method(worker, &block)
      return if worker.instance_methods.include?(:perform_with_event)

      yield worker
    end
  end
end
