module Chasqui

  HandlerAlreadyRegistered = Class.new StandardError

  class Subscriber
    attr_reader :queue, :channel

    def initialize(queue, channel)
      @queue = queue
      @channel = channel
    end

    def on(event_name, &block)
      pattern = pattern_for_event event_name 

      if handlers.key? pattern
        raise HandlerAlreadyRegistered.new "handler already registered for event: #{event_name}"
      else
        handlers[pattern] = block
      end
    end

    def perform(event)
      handlers_for(event['name']).each do |handler|
        handler.call *event['data']
      end
    end

    def handlers_for(event_name)
      handlers.select { |pattern, handler| pattern =~ event_name }.values
    end

    def evaluate(&block)
      @self_before_instance_eval = eval "self", block.binding
      instance_eval &block
    end

    private

    def handlers
      @handlers ||= {}
    end

    def method_missing(method, *args, &block)
      if @self_before_instance_eval
        @self_before_instance_eval.send method, *args, &block
      else
        super
      end
    end

    def pattern_for_event(event_name)
      /\A#{event_name.to_s.downcase.gsub('*', '.*')}\z/
    end

  end
end
