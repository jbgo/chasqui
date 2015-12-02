require 'spec_helper'

describe Chasqui::InlineSubscriber do
  before { reset_config }

  describe '.create' do
    before { Chasqui.config.channel_prefix = 'prefix' }

    it 'creates an inline subscriber' do
      block = Proc.new { |payload| payload[:a] + payload[:b] }
      inline = Chasqui::InlineSubscriber.create 'channel', 'queue', &block

      expect(inline).to be_kind_of(Chasqui::Subscriber)
      expect(inline.channel).to eq('prefix.channel')
      expect(inline.queue).to eq('queue')
      expect(inline.perform(a: 2, b: 2)).to eq(4)
    end
  end
end
