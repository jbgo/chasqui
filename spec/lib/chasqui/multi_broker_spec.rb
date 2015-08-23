require 'spec_helper'

describe Chasqui::MultiBroker do
  let(:broker) { Chasqui::MultiBroker.new }
  before { reset_chasqui }

  describe '#forward_event' do
    before do
      Chasqui.config.channel = 'app1'
      Chasqui.subscribe queue: 'queue1', channel: 'app1'
      Chasqui.subscribe queue: 'queue2', channel: 'app2'
      Chasqui.subscribe queue: 'queue3', channel: 'app1'
    end

    it 'places the event on all subscriber queues' do
      Chasqui.publish 'foo.bar', 'A'
      broker.forward_event

      expect(redis.llen('inbox')).to eq(0)

      expect(redis.llen('queue:queue1')).to eq(1)
      expect(redis.llen('queue:queue2')).to eq(0)
      expect(redis.llen('queue:queue3')).to eq(1)

      event = { 'event' => 'foo.bar', 'channel' => 'app1', 'data' => ['A'] }

      job1 = JSON.parse redis.rpop('queue:queue1')
      expect(job1['args']).to include(event)

      job3 = JSON.parse redis.rpop('queue:queue3')
      expect(job3['args']).to include(event)
    end

    it 'blocks on empty queues' do
      thread = Thread.new { broker.forward_event }

      begin
        Timeout::timeout(1) do
          Chasqui.config.redis = Redis.new
          Chasqui.config.channel = 'app2'
          Chasqui.publish 'foo.bar', 'A'

          job = JSON.parse redis.brpop('queue:queue2')[1]
          expect(job).to include('class' => 'Chasqui::Subscriber__queue2')
          expect(job).to include('args' =>
            [{ 'event' => 'foo.bar', 'channel' => 'app2', 'data' => ['A'] }])
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
      expect(redis.llen('queue:queue2')).to eq(0)
      expect(redis.llen(broker.in_progress_queue)).to eq(1)

      allow(broker.redis).to receive(:smembers).and_call_original
      broker.forward_event
      expect(redis.llen('queue:queue2')).to eq(1)

      job = JSON.parse redis.rpop('queue:queue2')
      expect(job['args']).to include(
        'event' => 'foo', 'channel' => 'app2', 'data' => ['process'])
      expect(redis.llen(broker.in_progress_queue)).to eq(0)
    end
  end
end
