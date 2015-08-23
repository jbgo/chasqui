class Chasqui::ResqueWorker

  class << self

    # Factory method to create a Resque worker class for a Chasqui::Subscriber instance.
    def create(subscriber)
      class_name = "Subscriber__#{subscriber.queue}".to_sym
      return if Chasqui.const_defined? class_name

      worker = Class.new do
        @queue = subscriber.queue
        @subscriber = subscriber

        def self.perform(event)
          @subscriber.perform Resque.redis, event
        end
      end

      Chasqui.const_set class_name, worker
    end

  end

end
