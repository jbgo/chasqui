class Chasqui::ResqueWorker

  class << self

    # Factory method to create a Resque worker class for a Chasqui::Subscriber instance.
    def create(subscriber)
      find_or_build_worker(subscriber).tap do |worker|
        worker.class_eval do
          @queue = subscriber.queue
          @subscriber = subscriber

          def self.perform(event)
            @subscriber.perform Resque.redis, event
          end
        end
      end
    end

    private

    def find_or_build_worker(subscriber)
      class_name = class_name_for subscriber

      if Chasqui.const_defined? class_name
        Chasqui.const_get class_name
      else
        Class.new(Chasqui::ResqueWorker).tap do |worker|
          Chasqui.const_set class_name, worker
        end
      end
    end

    def class_name_for(subscriber)
      queue_name_constant = subscriber.queue.gsub(/[^\w]/, '_')
      "Subscriber__#{queue_name_constant}".to_sym
    end

  end

end
