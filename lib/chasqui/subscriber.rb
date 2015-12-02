module Chasqui
  class Subscriber
    extend Forwardable
    def_delegators 'self.class.subscriber_config', :channel, :queue

    def initialize(options={})
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
      SubscriberConfig = Struct.new :channel, :queue

      def subscriber_config
        @subscriber_config ||= SubscriberConfig.new(
          Chasqui.channel_prefix,
          Chasqui.default_queue
        )
      end

      def channel(name, options={})
        prefix = options.fetch :prefix, Chasqui.channel_prefix
        subscriber_config.channel = prefix ? "#{prefix}.#{name}" : name
      end

      def queue(name)
        subscriber_config.queue = name
      end
    end
  end
end
