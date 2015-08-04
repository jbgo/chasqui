$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'chasqui'

class FakeRedis
  def initialize
    @queues = {}
  end

  def rpush(key, value)
    queue(key) << value
  end

  def lpop(key)
    queue(key).shift
  end

  private

  def queue(key)
    @queues[key] ||= []
    @queues[key]
  end
end
