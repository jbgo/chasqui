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

# Newer versions of sidekiq only support newer versions of ruby
# https://github.com/mperham/sidekiq/blob/master/Changes.md#322
def sidekiq_supported_ruby_version?
  Gem::Version.new(RUBY_VERSION) > Gem::Version.new('1.9.3')
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
