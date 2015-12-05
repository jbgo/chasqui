require 'spec_helper'

describe Chasqui::QueueAdapters::Redis do
  it_behaves_like 'a queue adapter'

  let(:subscriber) do
    Class.new(Chasqui::Subscriber) do
      channel 'channel-name'
      queue 'queue-name'
    end.new
  end

  describe '#bind / #unbind' do
    let(:key) { 'subscriptions:channel-name' }

    context 'resque backend' do
      before do
        reset_chasqui
        Chasqui.config.worker_backend = :resque
      end

      it 'persists the subscriptions to redis' do
        subject.bind(subscriber)
        subscriptions = redis.smembers(key)
        expect(subscriptions).to eq(['resque/resque:queue-name'])

        redis.sadd key, 'random'

        subject.unbind(subscriber)
        subscriptions = redis.smembers('subscriptions:channel-name')
        expect(subscriptions).to eq(['random'])
      end
    end

    if sidekiq_supported_ruby_version?
      context 'sidekiq backend' do
        before do
          reset_chasqui
          Chasqui.config.worker_backend = :sidekiq
        end

        it 'persists the subscription to redis' do
          subject.bind(subscriber)
          subscriptions = redis.smembers('subscriptions:channel-name')
          expect(subscriptions).to eq(['sidekiq/queue-name'])

          redis.sadd key, 'random'

          subject.unbind(subscriber)
          subscriptions = redis.smembers('subscriptions:channel-name')
          expect(subscriptions).to eq(['random'])
        end
      end
    end
  end

end
