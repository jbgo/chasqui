require 'spec_helper'
require 'sidekiq'

if sidekiq_supported_ruby_version?

  describe Chasqui::SidekiqWorker do
    let(:subscriber) { FakeSubscriber.new 'my-queue', 'my.channel'}

    describe '.create' do
      it 'configures a new worker' do
        worker_class = Chasqui::SidekiqWorker.create(subscriber)
        expect(worker_class.included_modules).to include(Sidekiq::Worker)
        expect(worker_class.sidekiq_options).to include('queue' => 'my-queue')
      end
    end

    describe '#perform' do
      let(:worker_class) { Chasqui::SidekiqWorker.create(subscriber) }

      it 'delegates to the subscriber' do
        event = { 'event' => 'foo', 'data' => ['bar'] }
        worker = worker_class.new
        worker.perform event
        received_event = subscriber.events.shift
        expect(received_event).to eq(event)
      end
    end
  end

end
