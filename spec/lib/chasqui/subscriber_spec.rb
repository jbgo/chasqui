require 'spec_helper'

describe Chasqui::Subscriber do
  subject { Chasqui::Subscriber.new 'foo', 'bar', 'worker' }

  it { expect(subject.channel).to eq('foo') }
  it { expect(subject.queue).to eq('bar') }
  it { expect(subject.worker).to eq('worker') }
end
