require 'spec_helper'

describe Chasqui::SubscriptionBuilder do
  describe '.builder' do
    let(:subscriptions) { double }
    let(:options) { { foo: 'bar' } }

    before { reset_config }

    context 'resque' do
      it do
        Chasqui.config.worker_backend = :resque

        builder = described_class.builder subscriptions, options
        expect(builder.subscriptions).to eq(subscriptions)
        expect(builder.default_options).to eq(options)
        expect(builder).to be_instance_of(Chasqui::ResqueSubscriptionBuilder)
      end
    end

    context 'sidekiq' do
      it do
        Chasqui.config.worker_backend = :sidekiq

        builder = described_class.builder subscriptions, options
        expect(builder.subscriptions).to eq(subscriptions)
        expect(builder.default_options).to eq(options)
        expect(builder).to be_instance_of(Chasqui::SidekiqSubscriptionBuilder)
      end
    end

    context 'neither' do
      it do
        Chasqui.config.worker_backend = :unknown
        expect(-> {
          described_class.builder subscriptions, options
        }).to raise_error(Chasqui::ConfigurationError)
      end
    end
  end
end
