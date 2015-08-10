require 'optparse'
require 'ostruct'
require 'chasqui'

class Chasqui::CLI
  extend Forwardable
  def_delegators :@options, :logfile, :redis_url, :inbox_queue, :debug, :version

  def initialize(argv)
    build_options(argv)
  end

  def configure
    Chasqui.configure do |config|
      config.logger = options.logfile if options.logfile
      config.redis = options.redis_url if options.redis_url
      config.inbox_queue = options.inbox_queue if options.inbox_queue
      config.logger.level = Logger::DEBUG if options.debug
    end
  end

  def run
    configure

    if options.version
      puts "chasqui #{Chasqui::VERSION}"
    elsif options.help
      puts @parser.help()
    else
      Chasqui::Broker.start
    end
  rescue => ex
    Chasqui.logger.fatal ex.inspect
    Chasqui.logger.fatal ex.backtrace.join("\n")
  end

  private

  def options
    @options ||= build_options
  end

  def build_options(argv)
    opts = {}

    @parser = OptionParser.new do |o|
      o.banner = "Usage: #{argv[0]} [options]"

      o.on('-f', '--logfile PATH', 'log file path') do |arg|
        opts[:logfile] = arg
      end

      o.on('-r', '--redis URL', 'redis connection URL') do |arg|
        opts[:redis_url] = arg
      end

      o.on('-q', '--inbox-queue NAME', 'name of the queue from which chasqui broker consumes events') do |arg|
        opts[:inbox_queue] = arg
      end

      o.on('-d', '--debug', 'enable debug logging') do |arg|
        opts[:debug] = arg
      end

      o.on('-v', '--version', 'show version and exit') do |arg|
        opts[:version] = arg
      end

      o.on('-h', '--help', 'show this help pessage') do |arg|
        opts[:help] = arg
      end
    end

    @parser.parse!(argv)
    @options = OpenStruct.new opts
  end

end
