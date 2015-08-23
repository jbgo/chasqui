require 'spec_helper'

describe Chasqui::Subscriber do
  let(:subscriber) { Chasqui::Subscriber.new 'my-queue', 'my.channel' }

  it { expect(subscriber.queue).to eq('my-queue') }
  it { expect(subscriber.channel).to eq('my.channel') }

  describe '#on' do
    it 'registers the event handlers' do
      subscriber.on('foo') { |foo| foo }
      subscriber.on('zig.zag') { |*args| args }

      pattern = subscriber.handlers_for('foo').first
      expect(subscriber.call_handler(pattern, 'bar')).to eq('bar')

      pattern = subscriber.handlers_for('zig.zag').first
      expect(subscriber.call_handler(pattern, 1, 2, 3, 4)).to eq([1, 2, 3, 4])
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
      expect(subscriber.handlers_for('foo')).to eq([/\Afoo\z/])
    end

    it 'matches wildcards' do
      p = 6.times.map { Proc.new { } }
      subscriber.on('foo*', &p[0])
      subscriber.on('bar', &p[1])
      subscriber.on('*bar', &p[2])
      subscriber.on('*', &p[3])
      subscriber.on('*a*', &p[4])
      subscriber.on('*z*', &p[5])
      expect(subscriber.handlers_for('foo.bar')).to eq([
        /\Afoo.*\z/,
        /\A.*bar\z/,
        /\A.*\z/,
        /\A.*a.*\z/
      ])
    end
  end

  describe '#perform' do
    it 'calls the matching event handlers' do
      calls = []
      subscriber.on('foo.bar') { |a, b| calls << a + b }
      subscriber.on('foo.*') { |a, b| calls << a ** b }
      subscriber.perform(redis, { 'event' => 'foo.bar', 'data' => [3, 4] })
      expect(calls.sort).to eq([7, 81])
    end
  end

end
