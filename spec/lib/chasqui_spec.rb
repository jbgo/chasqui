require 'spec_helper'

describe Chasqui do
  it 'has a version number' do
    expect(Chasqui::VERSION).not_to be nil
  end

  describe '.config' do
    it 'returns a config object' do
      expect(Chasqui.config).to be_instance_of(Chasqui::Config)
    end
  end

  describe '.configure' do
    it 'yields a config object' do
      Chasqui.configure do |c|
        expect(c).to be_instance_of(Chasqui::Config)
      end
    end
  end

  describe 'config delegates' do
    Chasqui::CONFIG_SETTINGS.each do |setting|
      it "responds to #{setting}" do
        expect(Chasqui).to respond_to(setting)
      end
    end
  end

  describe '.publish' do
    before { reset_chasqui }

    it 'pushes messages to the inbox queue' do
      payloads = [
        [1, 2, {'foo'=>'bar'}],
        [3, 4, {'biz'=>'baz'}]
      ]

      payloads.each do |args|
        Chasqui.publish 'test.event', *args
      end

      payloads.each do |data|
        event = JSON.load Chasqui.redis.rpop('inbox')
        expect(event['event']).to eq('test.event')
        expect(event['channel']).to eq('__default')
        expect(event['data']).to eq(data)
        expect(event['created_at'].to_f).to be_within(0.01).of(Time.now.to_f)
        expect(event['retry']).to eq(true)
      end
    end

    it 'supports channels' do
      Chasqui.config.channel = 'my.app'
      Chasqui.publish 'test.event', :foo
      event = JSON.load Chasqui.redis.rpop('inbox')
      expect(event['event']).to eq('test.event')
      expect(event['channel']).to eq('my.app')
      expect(event['data']).to eq(['foo'])
    end

    it 'supports retries' do
      Chasqui.publish 'test.event', :foo, :bar, foo: 'bar', job_options: { retry: false }
      event = JSON.load Chasqui.redis.rpop('inbox')
      expect(event['retry']).to eq(false)
    end
  end

  describe '.subscribe' do
    before do
      reset_chasqui
      Resque.redis.namespace = :resque
      Chasqui.config.worker_backend = :resque
    end

    context 'with defaults' do
      it 'subscribes to events on the default channel' do
        sub = Chasqui.subscribe queue: 'my-queue'

        channel = Chasqui.config.channel
        queues = Chasqui.redis.smembers Chasqui.subscription_key(channel)
        expect(queues).to eq(['resque/resque:queue:my-queue'])
      end
    end

    context 'resque worker subscriptions' do
      before { Resque.redis.namespace = 'blah' }

      it 'creates subscriptions using the appropriate redis namespace' do
        sub1 = Chasqui.subscribe channel: 'com.example.admin', queue: 'app1-queue'
        sub2 = Chasqui.subscribe channel: 'com.example.admin', queue: 'app2-queue'
        sub3 = Chasqui.subscribe channel: 'com.example.video', queue: 'app1-queue'

        queues = Chasqui.redis.smembers Chasqui.subscription_key("com.example.admin")
        expect(queues.sort).to eq(['resque/blah:queue:app1-queue', 'resque/blah:queue:app2-queue'])

        queues = Chasqui.redis.smembers Chasqui.subscription_key("com.example.video")
        expect(queues).to eq(['resque/blah:queue:app1-queue'])

        expect(Chasqui.subscription('app1-queue')).to eq(sub1)
        expect(Chasqui.subscription('app2-queue')).to eq(sub2)
        expect(sub1).to eq(sub3)
      end
    end

    if sidekiq_supported_ruby_version?
      context 'sidekiq worker subscriptions' do
        before do
          Chasqui.config.worker_backend = :sidekiq
        end

        it 'creates subscriptions using the appropriate redis namespace' do
          Chasqui.subscribe channel: 'com.example.admin', queue: 'app1-queue'
          queues = Chasqui.redis.smembers Chasqui.subscription_key("com.example.admin")
          expect(queues.sort).to eq(['sidekiq/queue:app1-queue'])

          Sidekiq.redis = { url: redis.client.options[:url], namespace: 'foobar' }
          Chasqui.subscribe channel: 'com.example.video', queue: 'app2-queue'
          queues = Chasqui.redis.smembers Chasqui.subscription_key("com.example.video")
          expect(queues.sort).to eq(['sidekiq/foobar:queue:app2-queue'])
        end
      end
    end

    it 'returns a subscription' do
      subscription = Chasqui.subscribe channel: 'com.example.admin', queue: 'app1-queue'
      expect(subscription.subscriber).to be_kind_of(Chasqui::Subscriber)
    end

    it 'yields a subscriber configuration context' do
      $context = nil
      Chasqui.subscribe channel: 'bar', queue: 'foo' do
        $context = self
      end
      expect($context).to be_kind_of(Chasqui::Subscriber)
    end
  end

  describe '.unsubscribe' do
    before do
      reset_chasqui
      Chasqui.config.worker_backend = :resque
      Resque.redis.namespace = 'ns0'
      Chasqui.subscribe channel: 'com.example.admin', queue: 'app1-queue'
      Chasqui.subscribe channel: 'com.example.admin', queue: 'app2-queue'
      Chasqui.subscribe channel: 'com.example.video', queue: 'app1-queue'
    end

    it 'removes the subscription' do
      subscription_id = Chasqui.unsubscribe 'com.example.admin', queue: 'app1-queue'
      expect(subscription_id).to eq('resque/ns0:queue:app1-queue')
      expect(redis.smembers(Chasqui.subscription_key 'com.example.admin').sort).to eq(['resque/ns0:queue:app2-queue'])
      expect(redis.smembers(Chasqui.subscription_key 'com.example.video').sort).to eq(['resque/ns0:queue:app1-queue'])
    end

    it 'returns nil for unknown subscriptions' do
      subscription_id = Chasqui.unsubscribe 'unknown', queue: 'unknown'
      expect(subscription_id).to be nil
    end
  end

  describe '.subscriber_class_name' do
    it 'transforms queue name into a subscribe class name' do
      expect(Chasqui.subscriber_class_name('my-queue')).to eq(:Subscriber__my_queue)
      expect(Chasqui.subscriber_class_name('queue:my-queue')).to eq(:Subscriber__my_queue)
    end
  end
end
