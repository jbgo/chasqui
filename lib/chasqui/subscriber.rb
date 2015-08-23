require 'set'

module Chasqui

  HandlerAlreadyRegistered = Class.new StandardError

  class Subscriber
    attr_accessor :redis, :current_event
    attr_reader :queue, :channel

    def initialize(queue, channel)
      @queue = queue
      @channel = channel
    end

    def on(event_name, &block)
      pattern = pattern_for_event event_name

      if handlers.include? pattern
        raise HandlerAlreadyRegistered.new "handler already registered for event: #{event_name}"
      else
        handlers << pattern
        self.class.send :define_method, "handler__#{pattern.to_s}", &block
      end
    end

    def perform(redis_for_worker, event)
      self.redis = redis_for_worker
      self.current_event = event

      handlers_for(event['event']).each do |pattern|
        send "handler__#{pattern.to_s}", *event['data']
      end
    end

    def handlers_for(event_name)
      handlers.select do |pattern|
        pattern =~ event_name
      end
    end

    def evaluate(&block)
      @self_before_instance_eval = eval "self", block.binding
      instance_eval &block
    end

    private

    def handlers
      @handlers ||= Set.new
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
