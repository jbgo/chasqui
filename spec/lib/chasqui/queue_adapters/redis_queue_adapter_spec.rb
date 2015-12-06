require 'spec_helper'

class MySubscriber < Chasqui::Subscriber
  channel 'channel-name'
  queue 'queue-name'
end

describe Chasqui::QueueAdapters::RedisQueueAdapter do
  it_behaves_like 'a queue adapter'

  let(:subscriber) { MySubscriber }

  describe '#bind / #unbind' do
    let(:key) { 'subscriptions:channel-name' }

    before { reset_chasqui_workers }
    after { reset_chasqui_workers }

    context 'resque backend' do
      before do
        reset_chasqui
        Chasqui.config.worker_backend = :resque
        Resque.redis.namespace = :resque
      end

      it 'persists the subscriptions to redis' do
        subject.bind(subscriber)
        subscriptions = redis.smembers(key)
        expect(subscriptions).to eq(
          ['resque/Chasqui::Workers::MySubscriber/resque:queue:queue-name'])

        expect(Chasqui::Workers.constants).to include(:MySubscriber)
        worker = Chasqui::Workers.const_get :MySubscriber
        expect(worker.subscriber).to eq(MySubscriber)

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
          Sidekiq.configure_client { |c| c.redis = { namespace: nil } }
        end

        it 'persists the subscription to redis' do
          subject.bind(subscriber)
          subscriptions = redis.smembers('subscriptions:channel-name')
          expect(subscriptions).to eq(
            ['sidekiq/Chasqui::Workers::MySubscriber/queue:queue-name'])
          expect(redis_no_namespace.smembers 'queues').to eq(['queue-name'])

          expect(Chasqui::Workers.constants).to include(:MySubscriber)
          worker = Chasqui::Workers.const_get :MySubscriber
          expect(worker.subscriber).to eq(MySubscriber)

          redis.sadd key, 'random'

          subject.unbind(subscriber)
          subscriptions = redis.smembers('subscriptions:channel-name')
          expect(subscriptions).to eq(['random'])
        end
      end
    end
  end

end
