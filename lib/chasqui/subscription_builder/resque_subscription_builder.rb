module Chasqui
  class ResqueSubscriptionBuilder < SubscriptionBuilder
    def get_queue_name(worker)
      worker.instance_variable_get :@queue
    end

    def set_queue_name(worker, queue)
      worker.instance_variable_set :@queue, queue
    end

    def define_worker_class(channel, callable, options)
      Class.new do
        @queue = Chasqui.default_queue
        define_singleton_method :perform, callable
      end
    end
  end
end
