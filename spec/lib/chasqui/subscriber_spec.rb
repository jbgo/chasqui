require 'spec_helper'

describe Chasqui::Subscriber do
  let(:subscriber_class) { Class.new { include Chasqui::Subscriber } }
  let(:redis) { Redis.new }

  describe '#event' do
    it { expect(subscriber_class.new(event: 'foo').event).to eq('foo') }
    it { expect(-> { subscriber_class.new }).to raise_error(KeyError) }
  end

  describe '#redis' do
    let(:subscriber) { subscriber_class.new event: nil }

    context 'default' do
      it { expect(subscriber.redis).to eq(Chasqui.redis) }
    end

    context 'custom' do
      let(:redis) { Redis.new }
      let(:subscriber)  { subscriber_class.new event: nil, redis: redis }
      it { expect(subscriber.redis.object_id).to eq(redis.object_id) }
    end
  end

  describe '#logger' do
    let(:subscriber) { subscriber_class.new event: nil }

    context 'default' do
      it { expect(subscriber.logger).to eq(Chasqui.logger) }
    end

    context 'custom' do
      let(:logger) { FakeLogger.new }
      let(:subscriber) { subscriber_class.new event: nil, logger: logger }
      it { expect(subscriber.logger).to eq(logger) }
    end
  end

  describe '.channels' do
    before do
      expect(Chasqui).to receive(:register).with(subscriber_class).at_least(:once)
      subscriber_class.subscribe channel: 'some.channel'
    end

    context 'default' do
      it { expect(subscriber_class.channels).to include('some.channel') }
    end

    context 'with default prefix' do
      before do
        Chasqui.config.channel_prefix = 'prefix'
        subscriber_class.subscribe channel: 'some.channel'
      end

      it { expect(subscriber_class.channels).to include('prefix.some.channel') }
    end

    context 'with custom prefix' do
      before { Chasqui.config.channel_prefix = 'prefix' }

      it 'uses the custom prefix' do
        subscriber_class.subscribe channel: 'another.channel', prefix: 'custom'
        expect(subscriber_class.channels).to include('custom.another.channel')
      end

      it 'removes the prefix' do
        subscriber_class.subscribe channel: 'another.channel', prefix: nil
        expect(subscriber_class.channels).to include('another.channel')
      end
    end

    context 'multiple channels' do
      before { subscriber_class.subscribe channel: ['foo', 'bar'], prefix: 'custom' }

      it 'subscribes to multiple channels' do
        expect(subscriber_class.channels).to eq(['custom.foo', 'custom.bar'])
      end
    end
  end

  describe '.queue' do
    context 'default' do
      it { expect(subscriber_class.queue).to eq(Chasqui.default_queue) }
    end

    context 'custom' do
      before do
        expect(Chasqui).to receive(:register).with(subscriber_class)
        subscriber_class.subscribe queue: 'custom-queue'
      end

      it { expect(subscriber_class.queue).to eq('custom-queue') }
    end
  end

  describe '#perform' do
    let(:subscriber) { subscriber_class.new event: nil }

    it 'is not implemented' do
      expect(-> {
        subscriber.perform foo: 'bar'
      }).to raise_error(NotImplementedError)
    end
  end

  describe '.inherited' do
    before { allow(Chasqui).to receive(:register) }

    it 'maintains a registry of inherited classes' do
      klass = Class.new do
        include Chasqui::Subscriber
        subscribe
      end

      expect(Chasqui::Subscriber.subscribers).to include(klass)
    end
  end
end
