require 'spec_helper'

describe Chasqui::Subscriber do
  let(:subscriber) { Chasqui::Subscriber.new 'my-queue', 'my.namespace' }

  it { expect(subscriber.queue).to eq('my-queue') }
  it { expect(subscriber.namespace).to eq('my.namespace') }

  describe '#on' do
    it 'registers the event handlers' do
      subscriber.on('foo') { |foo| foo }
      subscriber.on('zig.zag') { |*args| args }

      handler = subscriber.handlers_for('foo').first
      expect(handler.call('bar')).to eq('bar')

      handler = subscriber.handlers_for('zig.zag').first
      expect(handler.call(1, 2, 3, 4)).to eq([1, 2, 3, 4])
    end

    it 'raises when registering duplicate handlers' do
      subscriber.on('foo') { |foo| foo }
      expect(-> {
        subscriber.on('foo') { |a, b| a + b }
      }).to raise_error(Chasqui::HandlerAlreadyRegistered)
    end
  end

  describe '#handlers_for' do
    it 'always returns an array' do
      expect(subscriber.handlers_for('unknown')).to eq([])
    end

    it 'matches single event' do
      p = Proc.new { }
      subscriber.on('foo', &p)
      expect(subscriber.handlers_for('foo')).to eq([p])
    end

    it 'matches wildcards' do
      p = 6.times.map { Proc.new { } }
      subscriber.on('foo*', &p[0])
      subscriber.on('bar', &p[1])
      subscriber.on('*bar', &p[2])
      subscriber.on('*', &p[3])
      subscriber.on('*a*', &p[4])
      subscriber.on('*z*', &p[5])
      expect(subscriber.handlers_for('foo.bar')).to eq([p[0], p[2], p[3], p[4]])
    end
  end

  describe '#perform' do
    it 'calls the matching event handlers' do
      calls = []
      subscriber.on('foo.bar') { |a, b| calls << a + b }
      subscriber.on('foo.*') { |a, b| calls << a ** b }
      subscriber.perform({ 'name' => 'foo.bar', 'data' => [3, 4] })
      expect(calls.sort).to eq([7, 81])
    end
  end

end
