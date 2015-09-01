require 'spec_helper'
require 'integration/pubsub_examples'

describe "resque integration", integration: true do
  include_examples 'pubsub', :resque, :start_resque_workers

  def start_resque_workers
    @subscriber_queues.each do |queue|
      @pids << fork do
        ENV['CHASQUI_ENV'] = 'test'
        ENV['QUEUE'] = queue
        ENV['TERM_CHILD'] = '1'
        ENV['INTERVAL'] = '1'
        ENV['REDIS_NAMESPACE'] = "resque:#{queue}"
        ENV['REDIS_URL'] = @redis_url
        exec 'bundle', 'exec', 'rake', 'resque:work'
      end
    end
  end
end
