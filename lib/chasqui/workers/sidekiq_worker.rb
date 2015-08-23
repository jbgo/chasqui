class Chasqui::SidekiqWorker

  class << self

    def create(subscriber)
      Class.new(Chasqui::SidekiqWorker) do
        include Sidekiq::Worker
        sidekiq_options queue: subscriber.queue
        @subscriber = subscriber

        def perform(event)
          self.class.subscriber.perform "TODO: redis", event
        end

        private

        def self.subscriber
          @subscriber
        end
      end
    end

  end

end
