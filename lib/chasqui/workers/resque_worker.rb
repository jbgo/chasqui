class Chasqui::ResqueWorker

  class << self

    # Factory method to create a Resque worker class for a Chasqui::Subscriber instance.
    def create(subscriber)
      Class.new(self).tap do |worker|
        worker.class_eval do
          @queue = subscriber.queue
          @subscriber = subscriber

          def worker.perform(event)
            @subscriber.perform event
          end
        end
      end
    end
  end

end
