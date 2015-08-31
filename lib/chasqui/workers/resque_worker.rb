module Chasqui
  class ResqueWorker < Worker
    class << self

      def namespace
        Resque.redis.namespace
      end

      # Factory method to create a Resque worker class for a Chasqui::Subscriber instance.
      def create(subscriber)
        find_or_build_worker(subscriber, Chasqui::ResqueWorker).tap do |worker|
          worker.class_eval do
            @queue = subscriber.queue
            @subscriber = subscriber

            def self.perform(event)
              @subscriber.perform Resque.redis, event
            end
          end
        end
      end

    end
  end
end
