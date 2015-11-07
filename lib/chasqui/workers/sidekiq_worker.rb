module Chasqui
  class SidekiqWorker < Worker
    class << self

      def namespace
        Sidekiq.redis { |r| r.respond_to?(:namespace) ? r.namespace : nil }
      end

      def create(subscriber)
        register_sidekiq_queue subscriber.queue

        find_or_build_worker(subscriber, Chasqui::SidekiqWorker).tap do |worker|
          define_worker_class worker, subscriber
        end
      end

      private

      def define_worker_class(worker, subscriber)
        worker.class_eval do
          include Sidekiq::Worker
          sidekiq_options queue: subscriber.queue
          @subscriber = subscriber

          def perform(event)
            Sidekiq.redis do |r|
              self.class.subscriber.perform r, event
            end
          end

          private

          def self.subscriber
            @subscriber
          end
        end
      end

      def register_sidekiq_queue(queue_name)
        Sidekiq.redis { |r| r.sadd 'queues', queue_name }
      end

    end
  end
end
