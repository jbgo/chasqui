require 'spec_helper'
require 'integration/pubsub_examples'

if sidekiq_supported_ruby_version?
  describe "sidekiq integration", integration: true do
    include_examples 'pubsub', :start_sidekiq_workers

    def start_sidekiq_workers
      @pids << fork do
        ENV['REDIS_URL'] = @redis_url
        ENV['REDIS_NAMESPACE'] = 'sidekiq'

        exec 'bundle', 'exec', 'sidekiq',
          '--concurrency', '1',
          '--environment', 'test',
          '--queue', 'app1',
          '--queue', 'app2',
          '--logfile', 'tmp/sidekiq-spec.log',
          '--require', './spec/integration/setup/sidekiq.rb',
          '--verbose'
      end
    end
  end
end
