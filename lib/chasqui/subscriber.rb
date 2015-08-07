module Chasqui
  class Subscriber

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
