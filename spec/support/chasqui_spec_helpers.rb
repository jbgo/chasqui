module ChasquiSpecHelpers

  def reset_chasqui
    flush_redis
    reset_config
    reset_chasqui_workers
  end

  def reset_config
    Chasqui.instance_variable_set(:@config, nil)
    Chasqui.instance_variable_set(:@subscriptions, nil)
    Chasqui.config.logger = './tmp/test.log'
  end

  def reset_chasqui_workers
    Chasqui::Worker.workers.clear

    Chasqui::Workers.constants.each do |c|
      Chasqui::Workers.send :remove_const, c
    end
  end

  def redis
    Chasqui.redis
  end

  def redis_no_namespace
    redis.redis
  end
  alias nnredis redis_no_namespace

  def flush_redis
    nnredis.keys('*').each { |k| nnredis.del k }
  end

  def new_subscriber(class_name, options={})
    queue = options.fetch :queue
    channel = options.fetch :channel

    @subscriber_registry ||= {}

    if @subscriber_registry[class_name] && options[:force]
      Object.send :remove_const, class_name
      @subscriber_registry[class_name] = nil
    end

    @subscriber_registry[class_name] ||= Class.new
    
    @subscriber_registry[class_name].tap do |sub|
      sub.include Chasqui::Subscriber
      sub.subscribe channel: channel, queue: queue
    end
  end
end
