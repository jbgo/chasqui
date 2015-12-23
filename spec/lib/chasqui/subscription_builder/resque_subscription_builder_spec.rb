require 'spec_helper'

describe Chasqui::ResqueSubscriptionBuilder do
  resque_worker = Class.new { @queue = 'pubsub' }

  it_behaves_like 'a subscription builder', resque_worker

  def queue_name(worker)
    worker.instance_variable_get(:@queue)
  end

  def perform(worker, *perform_args)
    worker.perform *perform_args
  end
end
