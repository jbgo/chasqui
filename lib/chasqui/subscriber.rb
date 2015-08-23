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

      if handler_patterns.include? pattern
        raise HandlerAlreadyRegistered.new "handler already registered for event: #{event_name}"
      else
        handler_patterns << pattern
        define_handler_method pattern, &block
      end
    end

    def perform(redis_for_worker, event)
      self.redis = redis_for_worker
      self.current_event = event

      matching_handler_patterns_for(event['event']).each do |pattern|
        call_handler pattern, *event['data']
      end
    end

    def matching_handler_patterns_for(event_name)
      handler_patterns.select do |pattern|
        pattern =~ event_name
      end
    end

    def call_handler(pattern, *args)
      send "handler__#{pattern.to_s}", *args
    end

    def evaluate(&block)
      @self_before_instance_eval = eval "self", block.binding
      instance_eval &block
    end

    private

    def handler_patterns
      @handler_patterns ||= Set.new
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

    def define_handler_method(pattern, &block)
      self.class.send :define_method, "handler__#{pattern.to_s}", &block
    end

  end
end
