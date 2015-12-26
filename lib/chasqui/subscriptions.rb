module Chasqui
  class Subscriptions
    attr_reader :queue_adapter

    def initialize(queue_adapter)
      @subscriptions = {}
      @subscribers ||= {}
      @queue_adapter = queue_adapter
    end

    def register(subscriber)
      queue = subscriber.queue.to_s
      channel = subscriber.channel.to_s

      @subscriptions[queue] ||= {}
      @subscriptions[queue][channel] ||= {}
      @subscriptions[queue][channel][subscriber.worker] = subscriber

      @subscribers[subscriber.worker] = subscriber

      queue_adapter.bind subscriber
    end

    def unregister(subscriber)
      queue = subscriber.queue.to_s
      channel = subscriber.channel.to_s

      queue_adapter.unbind subscriber

      if @subscriptions[queue] && @subscriptions[queue][channel]
        @subscriptions[queue][channel].delete subscriber.worker
      end

      @subscribers.delete subscriber.worker
    end

    def find(channel, queue)
      @subscriptions[queue.to_s][channel.to_s].values
    end

    def subscribers
      @subscribers.values
    end

    def subscribed?(subscriber)
      @subscribers.key? subscriber.worker
    end
  end
end
