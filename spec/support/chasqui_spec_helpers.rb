module ChasquiSpecHelpers

  def reset_chasqui
    flush_redis
    reset_config
  end

  def reset_config
    Chasqui.instance_variable_set(:@config, nil)
    Chasqui.config.logger = './tmp/test.log'
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
