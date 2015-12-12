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

      def subscribe(args={})
        queue = args.fetch :queue, Chasqui.default_queue

        subscriber_config.channels = prefixed_channels args
        subscriber_config.queue = queue
      end

      def channels
        subscriber_config.channels
      end

      def queue
        subscriber_config.queue
      end

      def inherited(subclass)
        @subscribers ||= Set.new
        @subscribers << subclass
      end

      private

      def prefixed_channels(args)
        channel = args.fetch :channel, Chasqui.channel_prefix
        prefix = args.fetch :prefix, Chasqui.channel_prefix

        channels = channel.respond_to?(:each) ? channel : [channel]

        if prefix
          channels.map { |c| "#{prefix}.#{c}" }
        else
          channels
        end
      end
    end
  end
end
