require 'spec_helper'

class Worker1
  @queue = 'queue1'
  def self.perform(event, *args); end
end

class Worker2
  @queue = 'queue2'
  def self.perform(event, *args); end
end

class Worker3
  @queue = 'queue3'
  def self.perform(event, *args); end
end

describe Chasqui::RedisBroker do
  let(:broker) { Chasqui::RedisBroker.new }

  before do
    reset_chasqui
    Chasqui.config.worker_backend = :resque
    Resque.redis.namespace = nil
    allow(Time).to receive(:now).and_return(Time.now)
  end

  describe '#forward_event' do
    before do
      Chasqui.subscribe do
        on 'app1', Worker1
        on 'app2', Worker2
        on 'app1', Worker3
      end
    end

    it 'places the event on all subscriber queues' do
      Chasqui.publish 'app1', foo: 'bar'
      broker.forward_event

      expect(nnredis.llen(broker.inbox_queue)).to eq(0)

      expect(nnredis.llen('queue:queue1')).to eq(1)
      expect(nnredis.llen('queue:queue2')).to eq(0)
      expect(nnredis.llen('queue:queue3')).to eq(1)

      event = {
        'channel' => 'app1',
        'payload' => [{ 'foo' => 'bar' }],
        'created_at' => Time.now.to_f.to_s,
        'retry' => true
      }

      job1 = JSON.parse nnredis.lpop('queue:queue1')
      expect(job1['args']).to include(event)

      job3 = JSON.parse nnredis.lpop('queue:queue3')
      expect(job3['args']).to include(event)
    end

    it 'blocks on empty queues' do
      thread = Thread.new { broker.forward_event }

      begin
        Timeout::timeout(1) do
          Chasqui.config.redis = Redis.new
          Chasqui.publish 'app2', foo: 'bar'

          job = JSON.parse nnredis.blpop('queue:queue2')[1]
          expect(job).to include('class' => 'Worker2')

          event = {
            'channel' => 'app2',
            'payload' => [{ 'foo' => 'bar' }],
            'created_at' => Time.now.to_f.to_s,
            'retry' => true
          }

          expect(job).to include('args' => [event])
        end
      ensure
        thread.kill
      end
    end

    it "doesn't lose events if the broker fails" do
      Chasqui.publish 'app2', 'process'
      Chasqui.publish 'app2', 'keep in queue'
      allow(broker.redis).to receive(:smembers).and_raise(Redis::ConnectionError)

      expect(-> { broker.forward_event }).to raise_error(Redis::ConnectionError)
      expect(nnredis.llen('queue:queue2')).to eq(0)
      expect(nnredis.llen(broker.in_progress_queue)).to eq(1)

      allow(broker.redis).to receive(:smembers).and_call_original
      broker.forward_event
      expect(nnredis.llen('queue:queue2')).to eq(1)

      job = JSON.parse nnredis.lpop('queue:queue2')
      expect(job['args']).to include(
        'channel' => 'app2',
        'payload' => ['process'],
        'created_at' => Time.now.to_f.to_s,
        'retry' => true
      )
      expect(nnredis.llen(broker.in_progress_queue)).to eq(0)
    end

    it 'works when queue is empty' do
      Chasqui.config.broker_poll_interval = 1
      expect(-> { broker.forward_event }).not_to raise_error
    end
  end

  describe '#build_job' do
    it 'includes useful metadata' do
      event = { 'channel' => 'fox4', 'payload' => [] }
      job = JSON.parse broker.build_job('my-queue', 'MyWorker', event)

      expect(job['class']).to eq('MyWorker')
      expect(job['args']).to include(event)
      expect(job['queue']).to eq('my-queue')
      expect(job['jid']).to match(/^[0-9a-f]{24}/i)
      expect(job['created_at']).to be_within(0.01).of(Time.now.to_f)
      expect(job['enqueued_at']).to be_within(0.01).of(Time.now.to_f)
      expect(job['retry']).to be nil
    end

    it 'uses the event created_at time' do
      created_at = (Time.now - 3).to_f
      job = JSON.parse broker.build_job('my-queue', 'MyWorker', 'created_at' => created_at.to_s)
      expect(job['created_at']).to eq(created_at)
    end

    it 'uses the event retry value' do
      job = JSON.parse broker.build_job('my-queue', 'MyWorker', 'retry' => true)
      expect(job['retry']).to be true

      job = JSON.parse broker.build_job('my-queue', 'MyWorker', 'retry' => false)
      expect(job['retry']).to be false

      job = JSON.parse broker.build_job('my-queue', 'MyWorker', 'retry' => nil)
      expect(job['retry']).to be nil
    end
  end
end
