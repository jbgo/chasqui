$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'chasqui'
require 'pp'

def reset_chasqui
  reset_config
  flush_redis
end

def reset_config
  Chasqui.instance_variable_set(:@config, nil)
end

def redis
  Chasqui.redis
end

def flush_redis
  redis.keys('*').each { |k| redis.del k }
end
