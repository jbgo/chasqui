require 'spec_helper'

describe Chasqui::Subscription do

  def new_subscription(queue='default')
    Chasqui::Subscription.new queue, 'fake-channel', FakeSubscriber
  end

  describe '#worker' do
    it 'raises when no worker backend configured' do
      Chasqui.config.worker_backend = nil
      allow_any_instance_of(Chasqui::Subscription).to receive(
        :worker_backend).and_return(nil)

      expect(-> {
        new_subscription.worker
      }).to raise_error(Chasqui::ConfigurationError)
    end

    it 'creates a resque worker' do
      Chasqui.config.worker_backend = :resque
      worker = new_subscription('resque-queue').worker
      expect(worker.new).to be_kind_of(Chasqui::ResqueWorker)
    end

    if sidekiq_supported_ruby_version?
      it 'creates a sidekiq worker' do
        Chasqui.config.worker_backend = :sidekiq
        worker = new_subscription('sidekiq-queue').worker
        expect(worker.new).to be_kind_of(Chasqui::SidekiqWorker)
      end
    end
  end

end
