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

  describe '.subscriptions' do
    subject { Chasqui.subscriptions }

    it { should be_instance_of(Chasqui::Subscriptions) }
    it { expect(subject.queue_adapter).to be_instance_of(Chasqui::QueueAdapter::RedisQueueAdapter) }
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

      payloads.each do |payload|
        event = JSON.load Chasqui.redis.rpop(Chasqui.config.inbox_queue)
        expect(event['channel']).to eq('test.event')
        expect(event['payload']).to eq(payload)
        expect(event['created_at'].to_f).to be_within(0.1).of(Time.now.to_f)
        expect(event['retry']).to eq(true)
      end
    end

    it 'supports retries' do
      Chasqui.publish 'test.event', :foo, :bar, foo: 'bar', job_options: { retry: false }
      event = JSON.load Chasqui.redis.rpop(Chasqui.config.inbox_queue)
      expect(event['retry']).to eq(false)
    end
  end

  describe '.subscribe' do
    let(:fake_builder) do
      Class.new(Chasqui::SubscriptionBuilder) do
        def self.handlers
          @handlers ||= []
        end

        def on(channel, worker, options={})
          self.class.handlers << [channel, worker, options]
        end
      end
    end

    before { reset_config }

    it 'evaluates the block with a subscription builder binding' do
      results = {}
      worker = Class.new
      allow(Chasqui::SubscriptionBuilder).to receive(:builder)
        .and_return(fake_builder.new(nil))

      Chasqui.subscribe queue: 'foo' do
        results[:builder] = self
        on 'channel', worker
      end

      builder = results[:builder]
      expect(fake_builder.handlers.first).to eq(['channel', worker, {}])
    end
  end

  FakeWorker1 = Class.new
  FakeWorker2 = Class.new

  describe '.unsubscribe' do
    let(:subscriptions) { Chasqui.subscriptions }

    before do
      reset_chasqui
      Chasqui.config.queue_adapter = FakeQueueAdapter
      allow_any_instance_of(FakeQueueAdapter).to receive(:bind)
    end

    it 'unsubscribes all workers' do
      sub1 = Chasqui::Subscriber.new 'channel', 'queue', FakeWorker1
      sub2 = Chasqui::Subscriber.new 'channel', 'queue', FakeWorker2

      subscriptions.register sub1
      subscriptions.register sub2
      expect(subscriptions.find 'channel', 'queue').to eq([sub1, sub2])

      expect_any_instance_of(FakeQueueAdapter).to receive(:unbind).with(sub1)
      expect_any_instance_of(FakeQueueAdapter).to receive(:unbind).with(sub2)

      Chasqui.unsubscribe('channel', 'queue')
      expect(subscriptions.find 'channel', 'queue').to be_empty
    end

    it 'unsubscribes a single worker' do
      sub1 = Chasqui::Subscriber.new 'channel', 'queue', FakeWorker1
      sub2 = Chasqui::Subscriber.new 'channel', 'queue', FakeWorker2

      subscriptions.register sub1
      subscriptions.register sub2
      expect(subscriptions.find 'channel', 'queue').to eq([sub1, sub2])

      expect_any_instance_of(FakeQueueAdapter).to receive(:unbind).with(sub1)

      Chasqui.unsubscribe('channel', 'queue', FakeWorker1)
      expect(subscriptions.find 'channel', 'queue').to eq([sub2])
    end
  end
end
