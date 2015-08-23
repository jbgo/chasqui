require 'spec_helper'

describe Chasqui::Broker do
  let(:broker) { Chasqui::Broker.new }
  before { reset_chasqui }

  it 'forwards events to subscriber queues' do
    expect(-> { broker.forward_event }).to raise_error(NotImplementedError)
  end
end
