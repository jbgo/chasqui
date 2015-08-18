require 'spec_helper'

describe Chasqui::ResqueWorker do
  let(:subscriber) { FakeSubscriber.new 'my-queue', 'my.channel'}

  describe '.create' do
    it 'configures a new worker' do
      worker_class = Chasqui::ResqueWorker.create(subscriber)
      expect(worker_class.ancestors).to include(Chasqui::ResqueWorker)
      expect(worker_class.instance_variable_get(:@queue)).to eq('my-queue')
    end
  end

  describe '.perform' do
    let(:worker) { Chasqui::ResqueWorker.create(subscriber) }

    it 'delegates to the subscriber' do
      event = { 'event' => 'foo', 'data' => ['bar'] }
      worker.perform event
      received_event = subscriber.events.shift
      expect(received_event).to eq(event)
    end
  end

end
