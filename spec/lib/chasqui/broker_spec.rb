require 'spec_helper'

describe Chasqui::Broker do
  let(:broker) { Chasqui::Broker.new }
  pending 'it starts'
  pending 'it stops gracefully'
  pending 'it responds to signals gracefully'

  it 'forwards events to subscriber queues' do
    expect(-> { broker.forward_event }).to raise_error(NotImplementedError)
  end
end

describe Chasqui::MultiBroker do
  let(:broker) { Chasqui::MultiBroker.new }
  before { reset_chasqui }

  describe '#forward_event' do
    before do
      reset_chasqui
      Chasqui.config.namespace = 'app1'
      Chasqui.subscribe queue: 'queue1', namespace: 'app1'
      Chasqui.subscribe queue: 'queue2', namespace: 'app2'
      Chasqui.subscribe queue: 'queue3', namespace: 'app1'
    end

    it 'places the event on all subscriber queues' do
      Chasqui.publish 'foo.bar', 'A'
      broker.forward_event

      expect(redis.llen('inbox')).to eq(0)

      expect(redis.llen('queue1')).to eq(1)
      expect(redis.llen('queue2')).to eq(0)
      expect(redis.llen('queue3')).to eq(1)

      event = { 'event' => 'foo.bar', 'namespace' => 'app1', 'data' => ['A'] }
      expect(JSON.parse redis.rpop('queue1')).to include(event)
      expect(JSON.parse redis.rpop('queue3')).to include(event)
    end

    it 'blocks on empty queues' do
      thread = Thread.new { broker.forward_event }

      begin
        Timeout::timeout(1) do
          Chasqui.config.redis = Redis.new
          Chasqui.config.namespace = 'app2'
          Chasqui.publish 'foo.bar', 'A'

          expect(JSON.parse redis.brpop('queue2')[1]).to include(
            'event' => 'foo.bar', 'namespace' => 'app2', 'data' => ['A'])
        end
      ensure
        thread.kill
      end
    end

    it "doesn't lose events if the broker fails" do
      Chasqui.config.namespace = 'app2'
      Chasqui.publish 'foo', 'process'
      Chasqui.publish 'foo', 'keep in queue'
      allow(broker.redis).to receive(:smembers).and_raise(Redis::ConnectionError)

      expect(-> { broker.forward_event }).to raise_error(Redis::ConnectionError)
      expect(redis.llen('queue2')).to eq(0)
      expect(redis.llen(broker.in_progress_queue)).to eq(1)

      allow(broker.redis).to receive(:smembers).and_call_original
      broker.forward_event
      expect(redis.llen('queue2')).to eq(1)
      expect(redis.llen(broker.in_progress_queue)).to eq(0)
      expect(JSON.parse redis.rpop('queue2')).to include(
        'event' => 'foo', 'namespace' => 'app2', 'data' => ['process'])
    end
  end
end
