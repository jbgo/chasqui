module Chasqui
  module Chasqui::Workers
  end

  class Worker
    class << self

      BACKENDS = {
        resque: 'ResqueWorkerFactory',
        sidekiq: 'SidekiqWorkerFactory'
      }

      def create(subscriber)
        check_for_worker_backend
        new_class = worker_factory.create subscriber
        Chasqui::Workers.const_set subscriber.name, new_class
      end

      private

      def check_for_worker_backend
        unless BACKENDS.keys.include? Chasqui.worker_backend
          msg = "Chasqui.config.worker_backend must be one of #{BACKENDS.keys}"
          raise ConfigurationError.new msg
        end
      end

      def worker_factory
        Chasqui.const_get BACKENDS[Chasqui.worker_backend]
      end

    end
  end

  class ResqueWorkerFactory
    def self.create(subscriber)
      Class.new do
        @queue = subscriber.queue
        @subscriber = subscriber

        class << self
          attr_reader :subscriber
        end

        def self.perform(event)
          instance = @subscriber.new event: event, logger: Resque.logger
          instance.perform event['payload']
        end
      end
    end
  end

  class SidekiqWorkerFactory
    def self.create(subscriber)
      Class.new do
        include Sidekiq::Worker
        sidekiq_options 'queue' => 'foo-queue'

        @subscriber = subscriber

        class << self
          attr_reader :subscriber
        end

        def perform(event)
          instance = self.class.subscriber.new event: event, logger: logger
          instance.perform event['payload']
        end
      end
    end
  end

end
