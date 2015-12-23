require 'spec_helper'

describe Chasqui::SidekiqSubscriptionBuilder do
  sidekiq_worker = Class.new do
    include Sidekiq::Worker
    sidekiq_options queue: 'pubsub'

    def perform(event, *args)
    end
  end

  it_behaves_like 'a subscription builder', sidekiq_worker

  def queue_name(worker)
    worker.sidekiq_options['queue']
  end

  def perform(worker, *perform_args)
    worker.new.perform *perform_args
  end

  def expect_worker_to_support_backend(worker)
    expect(worker.included_modules).to include(Sidekiq::Worker)
  end
end
