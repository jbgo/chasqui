require 'spec_helper'

class MockSubscriber < Chasqui::Subscriber
  channel 'foo-channel', prefix: nil
  queue 'foo-queue'

  def perform(payload)
    self.class.info[:event] = event
    self.class.info[:payload] = payload
    self.class.info[:redis] = redis
    self.class.info[:logger] = logger
  end

  class << self
    def info
      @info ||= {}
    end
  end
end

describe Chasqui::Worker do
  before do
    reset_config
    Chasqui::Worker.workers.clear
    MockSubscriber.instance_variable_set :@info, nil
  end

  let(:subscriber) { MockSubscriber }

  context 'no worker backend' do
    describe '.create' do
      it 'raises' do
        Chasqui.config.worker_backend = :does_not_exist

        expect(-> {
          Chasqui::Worker.create subscriber
        }).to raise_error(Chasqui::ConfigurationError)
      end
    end
  end

  context 'resque' do
    before { Chasqui.config.worker_backend = :resque }
    after { Chasqui::Workers.send :remove_const, :MockSubscriber }

    describe '.create' do
      let(:worker) { Chasqui::Worker.create subscriber }

      it { expect(worker.name).to eq('Chasqui::Workers::MockSubscriber') }
      it { expect(worker.instance_variable_get(:@queue)).to eq(subscriber.queue) }
      it { expect(worker.instance_variable_get(:@subscriber)).to eq(subscriber) }

      it 'delegates #perform to the subscriber' do
        event = {
          'channel' => 'foo-channel',
          'payload' => { 'some' => 'data' }
        }

        worker.perform event

        expect(subscriber.info[:event]).to eq(event)
        expect(subscriber.info[:payload]).to eq(event['payload'])
      end
    end
  end

  if sidekiq_supported_ruby_version?
    context 'sidekiq' do
      before { Chasqui.config.worker_backend = :sidekiq }
      after { Chasqui::Workers.send :remove_const, :MockSubscriber }

      describe '.create' do
        let(:worker) { Chasqui::Worker.create subscriber }

        it { expect(worker.name).to eq('Chasqui::Workers::MockSubscriber') }
        it { expect(worker.instance_variable_get(:@subscriber)).to eq(subscriber) }
        it { expect(worker.sidekiq_options).to include('queue' => 'foo-queue') }
        it { expect(worker.included_modules).to include(Sidekiq::Worker) }

        it 'delegates #perform to the subscriber' do
          event = {
            'channel' => 'foo-channel',
            'payload' => { 'some' => 'data' }
          }

          sidekiq_worker = worker.new
          sidekiq_worker.perform event

          expect(subscriber.info[:event]).to eq(event)
          expect(subscriber.info[:payload]).to eq(event['payload'])
          expect(subscriber.info[:logger]).to eq(sidekiq_worker.logger)
        end
      end
    end
  end
end
