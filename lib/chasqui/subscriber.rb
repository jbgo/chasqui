module Chasqui
  class Subscriber < Struct.new(:channel, :queue, :worker)
  end
end
