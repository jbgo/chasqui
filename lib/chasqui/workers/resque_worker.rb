
class Chasqui::ResqueWorker

  class << self

    # Factory method to create a Resque worker class for a Chasqui::Subscriber instance.
    def create(subscriber)
      queue_name_constant = subscriber.queue.gsub(/[^\w]/, '_')
      class_name = "Subscriber__#{queue_name_constant}".to_sym

      worker = if Chasqui.const_defined? class_name
        Chasqui.const_get class_name
      else
        Class.new(Chasqui::ResqueWorker).tap do |new_worker|
          Chasqui.const_set class_name, new_worker
        end
      end

      worker.class_eval do
        @queue = subscriber.queue
        @subscriber = subscriber

        def self.perform(event)
          @subscriber.perform Resque.redis, event
        end
      end

      worker
    end

  end

end
