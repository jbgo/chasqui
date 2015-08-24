module ChasquiSpecHelpers

  def reset_chasqui
    reset_config
    flush_redis
  end

  def reset_config
    Chasqui.instance_variable_set(:@config, nil)
    Chasqui.config.logger = open('/dev/null', 'w+')
  end

  def redis
    Chasqui.redis
  end

  def flush_redis
    redis.keys('*').each { |k| redis.del k }
  end

end