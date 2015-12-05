module Chasqui
  module QueueAdapter
    def bind(subscriber)
      raise NotImplementedError
    end

    def unbind(subscriber)
      raise NotImplementedError
    end
  end
end
