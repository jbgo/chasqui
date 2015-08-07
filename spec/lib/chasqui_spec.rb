require 'spec_helper'

describe Chasqui do
  it 'has a version number' do
    expect(Chasqui::VERSION).not_to be nil
  end

  describe '.configure' do
    before { reset_config }

    context 'defaults' do
      it { expect(Chasqui.namespace).to be nil }
      it { expect(Chasqui.publish_queue).to eq('inbox') }
      it { expect(Chasqui.redis.client.db).to eq(0) }
    end

    it 'configures the namespace' do
      Chasqui.configure { |config| config.namespace = 'com.example.test' }
      expect(Chasqui.namespace).to eq('com.example.test')
    end

    context 'redis' do
      it 'accepts config options' do
        redis_config = { host: '10.0.3.24' }
        Chasqui.configure { |config| config.redis = redis_config }
        expect(Chasqui.redis.client.host).to eq('10.0.3.24')
      end

      it 'accepts an initialized client' do
        redis = Redis.new db: 2
        Chasqui.configure { |config| config.redis = redis }
        expect(Chasqui.redis.client.db).to eq(2)
      end

      it 'uses a namespace' do
        Chasqui.redis.set 'foo', 'bar'
        expect(Chasqui.redis.redis.get 'chasqui:foo').to eq('bar')
      end
    end
  end

  describe '.publish' do
    before do
      reset_config
      flush_redis
    end

    it 'pushes messages to the inbox queue' do
      payloads = [
        [1, 2, {'foo'=>'bar'}],
        [3, 4, {'biz'=>'baz'}]
      ]

      payloads.each do |args|
        Chasqui.publish 'test.event', *args
      end

      payloads.each do |data|
        event = JSON.load Chasqui.redis.lpop('inbox')
        expect(event['name']).to eq('test.event')
        expect(event['data']).to eq(data)
      end
    end

    it 'supports namespaces' do
      Chasqui.configure { |config| config.namespace = 'my.app' }
      Chasqui.publish 'test.event', :foo
      event = JSON.load Chasqui.redis.lpop('inbox')
      expect(event['name']).to eq('my.app.test.event')
      expect(event['data']).to eq(['foo'])
    end
  end

  private

  def reset_config
    Chasqui.instance_variable_set(:@config, nil)
  end

  def flush_redis
    Chasqui.redis.keys('*').each { |k| Chasqui.redis.del k }
  end

end
