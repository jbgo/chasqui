module Chasqui
  class Worker
    class << self

      def namespace
        raise NotImplementedError
      end

      def create(subscriber)
        raise NotImplementedError
      end

      def subscriber=(subscriber)
        raise NotImplementedError
      end

      protected

      def find_or_build_worker(subscriber, superclass)
        class_name = Chasqui.subscriber_class_name(subscriber.queue)

        if Chasqui.const_defined? class_name
          Chasqui.logger.warn "redefining subscriber class Chasqui::#{class_name}"
          Chasqui.send :remove_const, class_name
        end

        Class.new(superclass).tap do |worker|
          Chasqui.const_set class_name, worker
        end
      end

    end
  end
end
