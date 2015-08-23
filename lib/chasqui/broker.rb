require 'timeout'

class Chasqui::Broker
  attr_reader :config

  extend Forwardable
  def_delegators :@config, :redis, :inbox, :logger

  ShutdownSignals = %w(INT QUIT ABRT TERM).freeze

  # To prevent unsuspecting clients from blocking forever, the broker uses
  # it's own private redis connection.
  def initialize
    @shutdown_requested = nil
    @config = Chasqui.config.dup
    @config.redis = Redis.new @config.redis.client.options
  end

  def start
    install_signal_handlers

    logger.info "broker started with pid #{Process.pid}"
    logger.info "configured to fetch events from #{inbox} on #{redis.inspect}"

    until_shutdown_requested { forward_event }
  end

  def forward_event
    raise NotImplementedError.new "please define #forward_event in a subclass of #{self.class.name}"
  end

  class << self
    def start
      Chasqui::MultiBroker.new.start
    end
  end

  private

  def install_signal_handlers
    ShutdownSignals.each do |signal|
      trap(signal) { @shutdown_requested = signal }
    end
  end

  def until_shutdown_requested
    catch :shutdown do
      loop do
        with_timeout do
          if @shutdown_requested
            logger.info "broker received signal, #@shutdown_requested. shutting down"
            throw :shutdown
          else
            yield
          end
        end
      end
    end
  end

  def with_timeout
    # This timeout is a failsafe for an improperly configured broker
    Timeout::timeout(config.broker_poll_interval + 1) do
      yield
    end
  rescue TimeoutError
    logger.warn "broker poll interval exceeded for broker, #{self.class.name}"
  end

end
