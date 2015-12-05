require 'spec_helper'

if sidekiq_supported_ruby_version?

  describe Chasqui::SidekiqWorker do
    let(:subscriber) { FakeSubscriber.new 'my-queue', 'my.channel'}

    pending '.create' do
      before { flush_redis }

      it 'configures a new worker' do
        worker_class = Chasqui::SidekiqWorker.create(subscriber)
        expect(worker_class.name).to eq('Chasqui::Subscriber__my_queue')
        expect(worker_class.sidekiq_options).to include('queue' => 'my-queue')
        expect(worker_class.included_modules).to include(Sidekiq::Worker)
        expect(worker_class.new).to be_kind_of(Chasqui::SidekiqWorker)
        expect(redis_no_namespace.smembers 'queues').to eq(['my-queue'])
      end
    end

    pending '#perform' do
      let(:worker_class) { Chasqui::SidekiqWorker.create(subscriber) }

      it 'delegates to the subscriber' do
        event = { 'event' => 'foo', 'payload' => ['bar'] }
        worker = worker_class.new
        worker.perform event
        received_event = subscriber.events.shift
        expect(received_event).to eq(event)
      end
    end
  end

end
