require 'spec_helper'

describe Chasqui do
  it 'has a version number' do
    expect(Chasqui::VERSION).not_to be nil
  end

  describe '.configure' do
    before { reset_config }

    context 'defaults' do
      it { expect(Chasqui.namespace).to eq('__default') }
      it { expect(Chasqui.inbox_queue).to eq('inbox') }
      it { expect(Chasqui.redis.client.db).to eq(0) }
      it { expect(Chasqui.config.broker_poll_interval).to eq(3) }

      it do
        # remove chasqui's test environment logger
        Chasqui.config[:logger] = nil
        expect(Chasqui.logger).to be_kind_of(Logger)
      end

      it { expect(Chasqui.logger.level).to eq(Logger::INFO) }
      it { expect(Chasqui.logger.progname).to eq('chasqui') }
    end

    it 'configures the namespace' do
      Chasqui.config.namespace = 'com.example.test'
      expect(Chasqui.namespace).to eq('com.example.test')
    end

    it 'accepts a block' do
      Chasqui.configure { |config| config.namespace = 'com.example.test' }
      expect(Chasqui.namespace).to eq('com.example.test')
    end

    it 'configures the inbox queue' do
      Chasqui.config.inbox_queue = 'foo'
      expect(Chasqui.inbox).to eq('foo')
    end

    it 'configures the broker poll interval' do
      Chasqui.config.broker_poll_interval = 1
      expect(Chasqui.config.broker_poll_interval).to eq(1)
    end

    context 'redis' do
      it 'accepts config options' do
        redis_config = { host: '10.0.3.24' }
        Chasqui.config.redis = redis_config
        expect(Chasqui.redis.client.host).to eq('10.0.3.24')
      end

      it 'accepts an initialized client' do
        redis = Redis.new db: 2
        Chasqui.config.redis = redis
        expect(Chasqui.redis.client.db).to eq(2)
      end

      it 'accepts URLs' do
        Chasqui.config.redis = 'redis://10.0.1.21:12345/0'
        expect(Chasqui.redis.client.host).to eq('10.0.1.21')
      end

      it 'uses a namespace' do
        Chasqui.redis.set 'foo', 'bar'
        expect(Chasqui.redis.redis.get 'chasqui:foo').to eq('bar')
      end
    end

    describe 'logger' do
      it 'accepts a log device' do
        logs = StringIO.new
        Chasqui.config.logger = logs
        Chasqui.logger.info "status"
        Chasqui.logger.warn "error"

        logs.rewind
        output = logs.read

        %w(chasqui INFO status WARN error).each do |text|
          expect(output).to match(text)
        end
      end

      it 'accepts a logger-like object' do
        fake_logger = FakeLogger.new
        Chasqui.config.logger = fake_logger
        expect(Chasqui.logger).to eq(fake_logger)
        expect(Chasqui.logger.progname).to eq('chasqui')
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
        expect(event['namespace']).to eq('__default')
        expect(event['data']).to eq(data)
      end
    end

    it 'supports namespaces' do
      Chasqui.config.namespace = 'my.app'
      Chasqui.publish 'test.event', :foo
      event = JSON.load Chasqui.redis.rpop('inbox')
      expect(event['event']).to eq('test.event')
      expect(event['namespace']).to eq('my.app')
      expect(event['data']).to eq(['foo'])
    end
  end

  describe '.subscribe' do
    before { reset_chasqui }

    it 'saves subscriptions' do
      sub1 = Chasqui.subscribe queue: 'app1-queue', namespace: 'com.example.admin'
      sub2 = Chasqui.subscribe queue: 'app2-queue', namespace: 'com.example.admin'
      sub3 = Chasqui.subscribe queue: 'app1-queue', namespace: 'com.example.video'

      queues = Chasqui.redis.smembers "queues:com.example.admin"
      expect(queues.sort).to eq(['app1-queue', 'app2-queue'])

      queues = Chasqui.redis.smembers "queues:com.example.video"
      expect(queues).to eq(['app1-queue'])

      expect(Chasqui.subscriber('app1-queue')).to eq(sub1)
      expect(Chasqui.subscriber('app2-queue')).to eq(sub2)
      expect(sub1).to eq(sub3)
    end

    it 'returns a subscriber' do
      subscriber = Chasqui.subscribe queue: 'app1-queue', namespace: 'com.example.admin'
      expect(subscriber).to be_kind_of(Chasqui::Subscriber)
    end

    it 'yields a subscriber configuration context' do
      $context = nil
      Chasqui.subscribe queue: 'foo', namespace: 'bar' do
        $context = self
      end
      expect($context).to be_kind_of(Chasqui::Subscriber)
    end
  end
end

class FakeLogger
  attr_accessor :progname
  def info(*args, &block)
  end
end
