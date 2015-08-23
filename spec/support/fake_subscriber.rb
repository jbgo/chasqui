class FakeSubscriber < Chasqui::Subscriber
  attr_reader :events

  def initialize(queue, channel)
    super
    @events ||= []
  end

  def perform(redis, event)
    @events << event
  end
end
