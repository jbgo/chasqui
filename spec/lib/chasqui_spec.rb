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
    it do
      expect(Chasqui.subscriptions).to be_instance_of(Chasqui::Subscriptions)
    end
  end

  describe 'subscription management delegates' do
    [:register, :unregister].each do |m|
      it "delegates :#{m} to #subscriptions" do
        expect(Chasqui.subscriptions).to receive(m)
        Chasqui.send m
      end
    end
  end

  describe '.subscribe' do
    before do
      reset_config
      Chasqui.config.channel_prefix = 'prefix'
    end

    it 'registers an inline subscriber' do
      expect(Chasqui).to receive(:register) do |subscriber|
        expect(subscriber).to be_kind_of(Chasqui::InlineSubscriber)
        expect(subscriber.perform foo: 'bar').to eq('bar')
      end

      subscriber = Chasqui.subscribe 'a.channel' do |payload|
        payload[:foo]
      end
    end
  end

  pending '.unsubscribe' do
    it 'only unsubscribes inline subscribers'
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
        expect(event['channel']).to eq('test.event')
        expect(event['data']).to eq(data)
        expect(event['created_at'].to_f).to be_within(0.01).of(Time.now.to_f)
        expect(event['retry']).to eq(true)
      end
    end

    it 'supports retries' do
      Chasqui.publish 'test.event', :foo, :bar, foo: 'bar', job_options: { retry: false }
      event = JSON.load Chasqui.redis.rpop('inbox')
      expect(event['retry']).to eq(false)
    end
  end

end
