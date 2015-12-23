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
end
