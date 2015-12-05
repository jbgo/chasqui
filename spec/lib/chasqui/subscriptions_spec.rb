require 'spec_helper'

describe Chasqui::Subscriptions do
  let(:queue_adapter) { FakeQueueAdapter.new }

  subject { Chasqui::Subscriptions.new queue_adapter }

  let(:a) { OpenStruct.new channel: 'ch1', queue: 'foo' }
  let(:b) { OpenStruct.new channel: 'ch1', queue: 'bar' }
  let(:c) { OpenStruct.new channel: 'ch2', queue: 'foo' }
  let(:d) { OpenStruct.new channel: 'ch1', queue: 'foo' }

  before do
    [a, b, c, d].each do |subscriber|
      expect(queue_adapter).to receive(:bind).with(subscriber)
      subject.register subscriber
    end
  end

  it 'registers subscribers' do
    [a, b, c, d].each do |subscriber|
      expect(subject.subscribed? subscriber).to be true
    end

    expect(subject.subscribers.size).to eq(4)

    group1 = subject.find 'ch1', 'foo'
    expect(group1).to include(a)
    expect(group1).to include(d)

    group2 = subject.find 'ch1', 'bar'
    expect(group2.size).to eq(1)
    expect(subject.find 'ch1', 'bar').to include(b)

    group3 = subject.find 'ch2', 'foo'
    expect(group3.size).to eq(1)
    expect(subject.find 'ch2', 'foo').to include(c)
  end

  it 'unregisters subscribers' do
    [a, b, c].each do |subscriber|
      expect(queue_adapter).to receive(:unbind).with(subscriber)
      subject.unregister subscriber
      expect(subject.subscribed? subscriber).to be false
    end

    expect(subject.subscribed? d).to be true

    expect(subject.find 'ch1', 'bar').to be_empty
    expect(subject.find 'ch2', 'foo').to be_empty

    remaining = subject.find 'ch1', 'foo'
    expect(remaining.size).to eq(1)
    expect(remaining).to include(d)
  end

end
