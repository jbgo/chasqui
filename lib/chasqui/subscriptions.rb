module Chasqui
  class Subscriptions

    def initialize(queue_adapter)
      @subscriptions = {}
      @subscribers ||= {}
      @queue_adapter = queue_adapter
    end

    def register(subscriber)
      q = subscriber.queue.to_s
      c = subscriber.channel.to_s

      @subscriptions[q] ||= {}
      @subscriptions[q][c] ||= {}
      @subscriptions[q][c][subscriber.object_id] = subscriber

      @subscribers[subscriber.object_id] = subscriber

      queue_adapter.bind subscriber
    end

    def unregister(subscriber)
      q = subscriber.queue.to_s
      c = subscriber.channel.to_s

      queue_adapter.unbind subscriber

      if @subscriptions[q] && @subscriptions[q][c]
        @subscriptions[q][c].delete subscriber.object_id
      end

      @subscribers.delete subscriber.object_id
    end

    def find(channel, queue)
      @subscriptions[queue.to_s][channel.to_s].values
    end

    def subscribers
      @subscribers.values
    end

    def subscribed?(subscriber)
      @subscribers.key? subscriber.object_id
    end

    private

    attr_reader :queue_adapter
  end
end
