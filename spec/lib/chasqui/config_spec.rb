require 'spec_helper'

describe Chasqui::Config do

  context 'defaults' do
    it { expect(subject.channel_prefix).to be nil }
    it { expect(subject.default_queue).to eq('chasqui-subscribers') }
    it { expect(subject.inbox_queue).to eq('inbox') }
    it { expect(subject.redis.client.db).to eq(0) }
    it { expect(subject.broker_poll_interval).to eq(3) }
    it { expect(subject.worker_backend).to eq(nil) }
    it { expect(subject.queue_adapter).to eq(Chasqui::QueueAdapters::Redis) }

    it do
      # remove chasqui's test environment logger
      subject[:logger] = nil
      expect(subject.logger).to be_kind_of(Logger)
    end

    it { expect(subject.logger.level).to eq(Logger::INFO) }
    it { expect(subject.logger.progname).to eq('chasqui') }
  end

  it 'configures the channel prefix' do
    subject.channel_prefix = 'com.example.test'
    expect(subject.channel_prefix).to eq('com.example.test')
  end

  it 'configures the default queue' do
    subject.default_queue = 'my-app'
    expect(subject.default_queue).to eq('my-app')
  end

  it 'configures the inbox queue' do
    subject.inbox_queue = 'foo'
    expect(subject.inbox_queue).to eq('foo')
  end

  it 'configures the broker poll interval' do
    subject.broker_poll_interval = 1
    expect(subject.broker_poll_interval).to eq(1)
  end

  it 'configures the queue adapter' do
    subject.queue_adapter = FakeQueueAdapter
    expect(subject.queue_adapter).to eq(FakeQueueAdapter)
  end

  context 'redis' do
    it 'accepts config options' do
      redis_config = { host: '10.0.3.24' }
      subject.redis = redis_config
      expect(subject.redis.client.host).to eq('10.0.3.24')
    end

    it 'accepts an initialized client' do
      redis = Redis.new db: 2
      subject.redis = redis
      expect(subject.redis.client.db).to eq(2)
    end

    it 'accepts URLs' do
      subject.redis = 'redis://10.0.1.21:12345/0'
      expect(subject.redis.client.host).to eq('10.0.1.21')
    end

    it 'uses a namespace' do
      subject.redis.set 'foo', 'bar'
      expect(subject.redis.redis.get 'chasqui:foo').to eq('bar')
    end
  end

  describe 'logger' do
    it 'accepts a log device' do
      logs = StringIO.new
      subject.logger = logs
      subject.logger.info "status"
      subject.logger.warn "error"

      logs.rewind
      output = logs.read

      %w(chasqui INFO status WARN error).each do |text|
        expect(output).to match(text)
      end
    end

    it 'accepts a logger-like object' do
      fake_logger = FakeLogger.new
      subject.logger = fake_logger
      expect(subject.logger).to eq(fake_logger)
      expect(subject.logger.progname).to eq('chasqui')
    end
  end
end
