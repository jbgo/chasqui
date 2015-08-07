module Chasqui
  class Subscriber

    def on(event_name, &block)
      @handlers ||= {}
      @handlers[event_name] = block
    end

    def handlers_for(event_name)
      @handlers ||= {}
      keys = @handlers.keys.grep(/#{event_name.gsub('*', '.*')}/)
      keys.map { |k| @handlers[k] }
    end

    def evaluate(&block)
      @self_before_instance_eval = eval "self", block.binding
      instance_eval &block
    end

    def method_missing(method, *args, &block)
      if @self_before_instance_eval
        @self_before_instance_eval.send method, *args, &block
      else
        super
      end
    end

  end
end
