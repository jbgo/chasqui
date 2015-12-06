module Chasqui
  class Subscriber
    attr_reader :event

    def initialize(options={})
      @event = options.fetch(:event)

      @logger = options[:logger]
      @redis = options[:redis]
    end

    def redis
      @redis ||= Chasqui.redis
    end

    def logger
      @logger ||= Chasqui.logger
    end

    def perform(payload)
      raise NotImplementedError
    end

    class << self
      attr_reader :subscribers

      SubscriberConfig = Struct.new :channels, :queue

      def subscriber_config
        @subscriber_config ||= SubscriberConfig.new(
          Chasqui.channel_prefix,
          Chasqui.default_queue
        )
      end

      def channel(*names)
        options = names.last.kind_of?(Hash) ? names.pop : {}
        prefix = options.fetch :prefix, Chasqui.channel_prefix

        subscriber_config.channels = names.map do |name|
          prefix ? "#{prefix}.#{name}" : name
        end
      end

      def channels
        subscriber_config.channels
      end

      def queue(*args)
        if args.any?
          subscriber_config.queue = args.first
        else
          subscriber_config.queue
        end
      end

      def inherited(subclass)
        @subscribers ||= Set.new
        @subscribers << subclass
      end
    end
  end
end
