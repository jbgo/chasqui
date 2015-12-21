require 'spec_helper'

describe Chasqui::Sidekiq::SubscriptionBuilder do
  describe '#on' do
    let(:channel) { 'busy.channel' }
    let(:queue) { 'default' }
    let(:worker) { Class.new { include Sidekiq::Worker } }

    # TODO ensure this conforms to the subscriptions interface
    let(:subscriptions) { double }

    let(:builder) { described_class.new subscriptions }

    it 'subscribes the worker to the channel' do
      expect(subscriptions).to receive(:register).with(channel, worker, queue)

      builder.on channel, worker
    end

    it 'prefixes the queue name' do
      full_queue_name = "app_id:#{queue}"

      expect(subscriptions).to receive(:register).with(
        channel, worker, full_queue_name)

      builder.on channel, worker, queue_name_prefix: 'app_id'

      expect(worker.sidekiq_options['queue']).to eq(full_queue_name)
    end

    it 'uses a different queue' do
      expect(subscriptions).to receive(:register).with(
        channel, worker, 'other:queue')

      builder.on channel, worker, queue: 'other:queue'

      expect(worker.sidekiq_options['queue']).to eq('other:queue')
    end

    it 'does something expected when both options are used' do
      expect(subscriptions).to receive(:register).with(
        channel, worker, 'prefix:other:queue')

      builder.on channel, worker, queue: 'other:queue', queue_name_prefix: 'prefix'

      expect(worker.sidekiq_options['queue']).to eq('prefix:other:queue')
    end

    it 'converts a proc to a worker' do
      expect(subscriptions).to receive(:register) do |channel, worker, queue|
        expect(channel).to eq('busy.channel')
        expect(queue).to eq('app_id:default')

        expect(worker.included_modules).to include(Sidekiq::Worker)
        expect(worker.sidekiq_options['queue']).to eq('app_id:default')
        expect(worker.name).to eq('Chasqui::Workers::BusyChannelWorker')
        expect(worker.new.perform(3)).to eq(6)
      end

      builder.on channel, ->(x) { x + x }, queue_name_prefix: 'app_id'
    end
  end
end
