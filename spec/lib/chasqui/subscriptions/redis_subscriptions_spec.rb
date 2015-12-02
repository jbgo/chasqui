require 'spec_helper'

describe Chasqui::RedisSubscriptions do
  before { reset_chasqui }

  it { expect(subject).to be_kind_of(Chasqui::Subscriptions) }

  describe '#bind' do
    let(:subscriber) { OpenStruct.new queue: 'queue-name', channel: 'channel-name' }

    context 'no backend selected' do
      it 'raises' do
        expect(-> {
          subject.bind subscriber
        }).to raise_error(Chasqui::ConfigurationError)
      end
    end

    context 'resque' do
      before do
        Chasqui.config.worker_backend = :resque
        Resque.redis.namespace = 'namespace'
      end

      it 'binds the subscriber queue to the channel' do
        subject.bind subscriber
        queues = Chasqui.redis.smembers "subscribers:channel-name"
        expect(queues).to include('resque/namespace:queue:queue-name')
      end
    end

    if sidekiq_supported_ruby_version?
      context 'sidekiq' do
        before do
          Chasqui.config.worker_backend = :sidekiq
          Sidekiq.redis = { url: redis.client.options[:url], namespace: 'namespace' }
        end

        it 'binds the subscriber queue to the channel' do
          subject.bind subscriber
          queues = Chasqui.redis.smembers "subscribers:channel-name"
          expect(queues).to include('sidekiq/namespace:queue:queue-name')
        end
      end
    end
  end
end
