require 'spec_helper'

describe Chasqui::ResqueWorker do

  describe '.create' do
    let(:queue) { 'my-queue' }
    let(:subscriber) { Chasqui::Subscriber.new }

    it 'configures a new worker' do
      worker_class = Chasqui::ResqueWorker.create('my-queue', subscriber)
      expect(worker_class.ancestors).to include(Chasqui::ResqueWorker)
      expect(worker_class.instance_variable_get(:@queue)).to eq(queue)
    end
  end

  describe '#perform' do
    pending 'runs handlers for an event'
      # 1. subscribe to some events
      # 2. call perform directly
      # 3. inspect the results (handlers should have been called)
  end

end
