require 'spec_helper'

describe Chasqui::Subscriber do
  let(:subscriber_class) { Class.new(Chasqui::Subscriber) }
  let(:subscriber) { subscriber_class.new }
  let(:redis) { Redis.new }

  describe '#redis' do
    context 'default' do
      it { expect(subscriber.redis).to eq(Chasqui.redis) }
    end

    context 'custom' do
      let(:redis) { Redis.new }
      let(:subscriber)  { subscriber_class.new redis: redis }
      it { expect(subscriber.redis.object_id).to eq(redis.object_id) }
    end
  end

  describe '#logger' do
    context 'default' do
      it { expect(subscriber.logger).to eq(Chasqui.logger) }
    end

    context 'custom' do
      let(:logger) { FakeLogger.new }
      let(:subscriber) { subscriber_class.new logger: logger }
      it { expect(subscriber.logger).to eq(logger) }
    end
  end

  describe '#channels' do
    before { subscriber.class.channel 'some.channel' }

    context 'default' do
      it { expect(subscriber.channels).to include('some.channel') }
    end

    context 'with default prefix' do
      before do
        Chasqui.config.channel_prefix = 'prefix'
        subscriber.class.channel 'some.channel'
      end

      it { expect(subscriber.channels).to include('prefix.some.channel') }
    end

    context 'with custom prefix' do
      before { Chasqui.config.channel_prefix = 'prefix' }

      it 'uses the custom prefix' do
        subscriber.class.channel 'another.channel', prefix: 'custom'
        expect(subscriber.channels).to include('custom.another.channel')
      end

      it 'removes the prefix' do
        subscriber.class.channel 'another.channel', prefix: nil
        expect(subscriber.channels).to include('another.channel')
      end
    end

    context 'multiple channels' do
      before { subscriber.class.channel 'foo', 'bar', prefix: 'custom' }

      it 'subscribes to multiple channels' do
        expect(subscriber.channels).to eq(['custom.foo', 'custom.bar'])
      end
    end
  end

  describe '#queue' do
    context 'default' do
      it { expect(subject.queue).to eq(Chasqui.default_queue) }
    end

    context 'custom' do
      before { subject.class.queue 'custom-queue' }
      it { expect(subject.queue).to eq('custom-queue') }
    end
  end

  describe '#perform' do
    it 'is not implemented' do
      expect(-> {
        subscriber.perform foo: 'bar'
      }).to raise_error(NotImplementedError)
    end
  end

  describe '.inherited' do
    it 'maintains a registry of inherited classes' do
      klass = Class.new(Chasqui::Subscriber)
      expect(Chasqui::Subscriber.subscribers).to include(klass)
    end
  end
end
