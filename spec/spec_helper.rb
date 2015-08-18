$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'chasqui'
require 'pp'

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

class FakeSubscriber < Chasqui::Subscriber
  attr_reader :events

  def initialize(queue, channel)
    super
    @events ||= []
  end

  def perform(event)
    @events << event
  end
end
