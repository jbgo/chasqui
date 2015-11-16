module Chasqui
  class Subscription
    attr_reader :queue, :channel, :subscriber_type

    def initialize(queue, channel, subscriber_type=Chasqui::Subscriber)
      @queue = queue
      @channel = channel
      @subscriber_type = subscriber_type
    end

    def subscription_id
      queue_name = [worker.namespace, 'queue', queue].compact.join(':')
      "#{worker_backend}/#{queue_name}"
    end

    def subscriber
      @subscriber ||= subscriber_type.new queue, channel
    end

    def worker
      case worker_backend
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

    def worker_backend
      Chasqui.config.worker_backend || find_first_available_worker_backend
    end

    def find_first_available_worker_backend
      if Object.const_defined? :Sidekiq
        :sidekiq
      elsif Object.const_defined? :Resque
        :resque
      end
    end

    SUPPORTED_WORKER_BACKENDS = [:resque, :sidekiq].freeze

    def supported_worker_backends
      SUPPORTED_WORKER_BACKENDS.join(', ')
    end

  end
end
