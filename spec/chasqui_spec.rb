require 'spec_helper'

describe Chasqui do
  it 'has a version number' do
    expect(Chasqui::VERSION).not_to be nil
  end

  describe '.configure' do
    before { reset_config }

    context 'defaults' do
      it { expect(Chasqui.namespace).to be_nil }
      it { expect(Chasqui.publish_queue).to eq('chasqui.inbox') }
    end

    it 'configures the namespace' do
      Chasqui.configure { |config| config.namespace = 'com.example.test' }
      expect(Chasqui.namespace).to eq('com.example.test')
    end

    it 'configures redis' do
      redis = FakeRedis.new
      Chasqui.configure { |config| config.redis = redis }
      expect(Chasqui.redis).to eq(redis)
    end
  end

  describe '.publish' do
    before do
      reset_config
      Chasqui.configure { |config| config.redis = FakeRedis.new }
    end

    it 'publishes an event without a namespace' do
      Chasqui.publish 'test.event', 1, 2, foo: 'bar'
      event = JSON.load Chasqui.redis.lpop('chasqui.inbox')
      expect(event['name']).to eq('test.event')
      expect(event['data']).to eq([1, 2, {'foo'=>'bar'}])
    end

    it 'publishes an event with a namespace' do
      Chasqui.configure { |config| config.namespace = 'my.app' }
      p Chasqui.namespace
      Chasqui.publish 'test.event', :foo
      event = JSON.load Chasqui.redis.lpop('chasqui.inbox')
      expect(event['name']).to eq('my.app.test.event')
      expect(event['data']).to eq(['foo'])
    end
  end

  private

  def reset_config
    Chasqui.instance_variable_set(:@config, nil)
  end
end
