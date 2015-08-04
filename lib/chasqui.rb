require 'ostruct'
require 'json'
require "chasqui/version"

module Chasqui

  Config = Struct.new :namespace, :redis

  Defaults = {
    publish_queue: 'chasqui.inbox'
  }.freeze

  module ClassMethods
    def namespace
      @config.namespace unless @config.nil?
    end

    def redis
      @config.redis unless @config.nil?
    end

    def publish_queue
      Defaults[:publish_queue]
    end

    def configure(&block)
      @config ||= Config.new
      yield @config
    end

    def publish(event, *args)
      name = namespace ? "#{namespace}.#{event}" : event
      redis.rpush publish_queue, { name: name, data: args }.to_json
    end
  end

end

Chasqui.extend Chasqui::ClassMethods
