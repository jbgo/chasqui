module Chasqui
  class InlineSubscriber < Chasqui::Subscriber

    def self.create(channel, queue, &block)
      klass = Class.new(InlineSubscriber) do
        channel channel
        queue queue

        @@proc = Proc.new

        def perform(payload)
          @@proc.call payload
        end
      end

      klass.new
    end

  end
end
