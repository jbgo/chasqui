require 'spec_helper'

describe Chasqui::Subscriber do

  describe '#on' do
    let(:subscriber) { Chasqui::Subscriber.new }

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
    let(:subscriber) { Chasqui::Subscriber.new }

    it 'always returns an array' do
      expect(subscriber.handlers_for('unknown')).to eq([])
    end

    it 'matches single event' do
      p = Proc.new { }
      subscriber.on('foo', &p)
      expect(subscriber.handlers_for('foo')).to eq([p])
    end

    it 'matches wildcard postfixes' do
      p = 3.times.map { Proc.new { } }
      subscriber.on('foo', &p[0])
      subscriber.on('bar', &p[1])
      subscriber.on('foo.bar', &p[2])
      expect(subscriber.handlers_for('foo*')).to eq([p[0], p[2]])
    end

    it 'matches wildcard prefixes' do
      p = 3.times.map { Proc.new { } }
      subscriber.on('foo', &p[0])
      subscriber.on('bar', &p[1])
      subscriber.on('foo.bar', &p[2])
      expect(subscriber.handlers_for('*bar')).to eq([p[1], p[2]])
    end

    it 'matches all events' do
      p = 3.times.map { Proc.new { } }
      subscriber.on('foo', &p[0])
      subscriber.on('bar', &p[1])
      subscriber.on('foo.bar', &p[2])
      expect(subscriber.handlers_for('*')).to eq([p[0], p[1], p[2]])
    end
  end

end
