require 'spec_helper'
require 'chasqui/cli'

describe Chasqui::CLI do

  describe 'options' do
    before { reset_config }

    context do
      before { Chasqui.config.broker_poll_interval = 1 }
      after { File.unlink 'test.log' if File.exists? 'test.log' }

      it 'changes the logfile' do
        cli = Chasqui::CLI.new ['chasqui', '-f', 'test.log']
        expect(cli.logfile).to eq('test.log')

        cli.configure
        Chasqui.logger.warn 'test log message'
        expect(File.read('test.log')).to match('test log message')
      end
    end

    it 'changes the redis connection' do
        cli = Chasqui::CLI.new ['chasqui', '-r', 'redis://10.0.0.23:6379/5']
        expect(cli.redis_url).to eq('redis://10.0.0.23:6379/5')

        cli.configure
        expect(Chasqui.redis.redis.client.host).to eq('10.0.0.23')
    end

    it 'changes the inbox queue' do
        cli = Chasqui::CLI.new ['chasqui', '-q', 'inbox2']
        expect(cli.inbox_queue).to eq('inbox2')

        cli.configure
        expect(Chasqui.inbox).to eq('inbox2')
    end

    it 'enables verbose mode (debug logging)' do
        cli = Chasqui::CLI.new ['chasqui', '--debug']
        expect(cli.debug).to be true

        cli.configure
        expect(Chasqui.logger.level).to eq(Logger::DEBUG)
    end

    it 'displays the version' do
      cli = Chasqui::CLI.new ['chasqui', '-v']
      cli.run
      expect { cli.run }.to output(/chasqui #{Chasqui::VERSION}/).to_stdout
    end

    it 'displays help' do
      cli = Chasqui::CLI.new ['chasqui', '-h', '--help']
      expect { cli.run }.to output(/Usage: chasqui \[options\]/).to_stdout
    end
  end

  describe '#run' do
    before { reset_chasqui }

    it 'configures and starts the broker' do
      expect(Chasqui::Broker).to receive(:start)

      argv = %w(chasqui -f test.log --debug -q inbox2 -r redis://127.0.0.1:6379/0)
      Chasqui::CLI.new(argv).run

      expect(Chasqui.logger.level).to eq(Logger::DEBUG)
      expect(Chasqui.inbox_queue).to eq('inbox2')
      expect(Chasqui.redis.client.host).to eq('127.0.0.1')
    end
  end

end
