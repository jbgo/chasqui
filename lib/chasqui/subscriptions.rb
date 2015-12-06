module Chasqui
  class Subscriptions
    attr_reader :queue_adapter

    def initialize(queue_adapter)
      @subscriptions = {}
      @subscribers ||= {}
      @queue_adapter = queue_adapter
    end

    def register(subscriber)
      subscriber.channels.each do |channel|
        register_one channel, subscriber
      end
    end

    def unregister(subscriber)
      subscriber.channels.each do |channel|
        unregister_one channel, subscriber
      end
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

    def register_one(channel, subscriber)
      q = subscriber.queue.to_s
      c = channel.to_s

      @subscriptions[q] ||= {}
      @subscriptions[q][c] ||= {}
      @subscriptions[q][c][subscriber.object_id] = subscriber

      @subscribers[subscriber.object_id] = subscriber

      queue_adapter.bind subscriber
    end

    def unregister_one(channel, subscriber)
      q = subscriber.queue.to_s
      c = channel.to_s

      queue_adapter.unbind subscriber

      if @subscriptions[q] && @subscriptions[q][c]
        @subscriptions[q][c].delete subscriber.object_id
      end

      @subscribers.delete subscriber.object_id
    end
  end
end
