$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'chasqui'
require 'resque'
require 'pp'

Dir['spec/support/*.rb'].each { |file| require File.expand_path(file) }

RSpec.configure do |c|
  c.include ChasquiSpecHelpers
end
