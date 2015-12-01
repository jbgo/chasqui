require 'spec_helper'

describe Chasqui::MultiBroker do
  let(:broker) { Chasqui::MultiBroker.new }

  before do
    reset_chasqui
    Chasqui.config.worker_backend = :resque
    Resque.redis.namespace = nil
    allow(Time).to receive(:now).and_return(Time.now)
  end

  describe '#forward_event' do
    before do
      Chasqui.config.channel = 'app1'
      Chasqui.subscribe channel: 'app1', queue: 'queue1'
      Chasqui.subscribe channel: 'app2', queue: 'queue2'
      Chasqui.subscribe channel: 'app1', queue: 'queue3'
    end

    it 'places the event on all subscriber queues' do
      Chasqui.publish 'foo.bar', 'A'
      broker.forward_event

      expect(nnredis.llen(broker.inbox_queue)).to eq(0)

      expect(nnredis.llen('queue:queue1')).to eq(1)
      expect(nnredis.llen('queue:queue2')).to eq(0)
      expect(nnredis.llen('queue:queue3')).to eq(1)

      event = {
        'event' => 'foo.bar',
        'channel' => 'app1',
        'data' => ['A'],
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
          Chasqui.config.channel = 'app2'
          Chasqui.publish 'foo.bar', 'A'

          job = JSON.parse nnredis.blpop('queue:queue2')[1]
          expect(job).to include('class' => 'Chasqui::Subscriber__queue2')

          event = {
            'event' => 'foo.bar',
            'channel' => 'app2',
            'data' => ['A'],
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
      Chasqui.config.channel = 'app2'
      Chasqui.publish 'foo', 'process'
      Chasqui.publish 'foo', 'keep in queue'
      allow(broker.redis).to receive(:smembers).and_raise(Redis::ConnectionError)

      expect(-> { broker.forward_event }).to raise_error(Redis::ConnectionError)
      expect(nnredis.llen('queue:queue2')).to eq(0)
      expect(nnredis.llen(broker.in_progress_queue)).to eq(1)

      allow(broker.redis).to receive(:smembers).and_call_original
      broker.forward_event
      expect(nnredis.llen('queue:queue2')).to eq(1)

      job = JSON.parse nnredis.lpop('queue:queue2')
      expect(job['args']).to include(
        'event' => 'foo',
        'channel' => 'app2',
        'data' => ['process'],
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
      event = { 'event' => 'foo', 'channel' => 'bar', 'data' => [] }
      job = JSON.parse broker.build_job('my-queue', event)

      expect(job['class']).to eq('Chasqui::Subscriber__my_queue')
      expect(job['args']).to include(event)
      expect(job['queue']).to eq('my-queue')
      expect(job['jid']).to match(/^[0-9a-f]{24}/i)
      expect(job['created_at']).to be_within(0.01).of(Time.now.to_f)
      expect(job['enqueued_at']).to be_within(0.01).of(Time.now.to_f)
      expect(job['retry']).to be nil
    end

    it 'uses the event created_at time' do
      created_at = (Time.now - 3).to_f
      job = JSON.parse broker.build_job('my-queue', 'created_at' => created_at.to_s)
      expect(job['created_at']).to eq(created_at)
    end

    it 'uses the event retry value' do
      job = JSON.parse broker.build_job('my-queue', 'retry' => true)
      expect(job['retry']).to be true

      job = JSON.parse broker.build_job('my-queue', 'retry' => false)
      expect(job['retry']).to be false

      job = JSON.parse broker.build_job('my-queue', 'retry' => nil)
      expect(job['retry']).to be nil
    end
  end
end
