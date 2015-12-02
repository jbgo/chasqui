require 'spec_helper'
require 'resque'

describe Chasqui::ResqueWorker do
  let(:subscriber) { FakeSubscriber.new 'my-queue', 'my.channel'}

  pending '.create' do
    it 'configures a new worker' do
      worker_class = Chasqui::ResqueWorker.create(subscriber)
      expect(worker_class.name).to eq('Chasqui::Subscriber__my_queue')
      expect(worker_class.ancestors).to include(Chasqui::ResqueWorker)
      expect(worker_class.instance_variable_get(:@queue)).to eq('my-queue')
    end
  end

  pending '.perform' do
    let(:worker) { Chasqui::ResqueWorker.create(subscriber) }

    it 'delegates to the subscriber' do
      event = { 'event' => 'foo', 'data' => ['bar'] }
      worker.perform event
      received_event = subscriber.events.shift
      expect(received_event).to eq(event)
    end
  end

end
