require 'spec_helper'

shared_examples 'pubsub' do |start_workers_method|

  def events_to_publish
    [
      { channel: 'user.signup',    payload: ['Kelly'] },
      { channel: 'account.credit', payload: [1337, 'Kelly'] },
      { channel: 'account.debit',  payload: [10, 'Kelly'] },
      { channel: 'user.signup',    payload: ['Travis'] },
      { channel: 'account.debit',  payload: [9000, 'Kelly'] },
      { channel: 'user.cancel',    payload: ['Kelly'] },
      { channel: 'account.credit', payload: [42, 'Travis'] },
    ]
  end

  def expected_events
    {
      'app1' => [
        { channel: 'user.signup', payload: ['Kelly'] },
        { channel: 'user.signup', payload: ['Travis'] },
      ],
      'app2' => [
        { channel: 'account.credit', payload: [1337, 'Kelly'] },
        { channel: 'account.debit',  payload: [10, 'Kelly'] },
        { channel: 'account.debit',  payload: [9000, 'Kelly'] },
        { channel: 'user.cancel',    payload: ['Kelly'] },
        { channel: 'account.credit', payload: [42, 'Travis'] },
      ],
    }
  end

  before do
    @subscriber_queues = %w(app1 app2)
    @redis_url = 'redis://localhost:6379/13'
    @redis = Redis.new url: @redis_url
    @redis.keys('*').each { |k| @redis.del k }

    Chasqui.configure do |c|
      c.channel_prefix = 'integration'
      c.redis = @redis_url
    end

    @pids = []
    send start_workers_method

    # Wait for subscribers to register before starting the broker so we don't miss events.
    sleep 1

    start_chasqui_broker
  end

  after do
    terminate_child_processes
  end

  it 'works' do
    events_to_publish.each do |event|
      Chasqui.publish event[:channel], *event[:payload]
    end

    begin
      Timeout::timeout(10) do
        expected_events.each do |subscriber_queue, events|
          events.each do |expected|
            _, payload = Chasqui.redis.blpop "#{subscriber_queue}:event_log"
            actual = JSON.parse payload
            expect(actual['channel']).to eq(expected[:channel])
            expect(actual['payload']).to eq(expected[:payload])
          end
        end
      end
    rescue TimeoutError
      terminate_child_processes
      fail "Failed to process all events in a timely manner."
    end
  end

  def start_chasqui_broker
    @pids << fork do
      exec './bin/chasqui',
        '--logfile', 'tmp/integration.log',
        '--redis', @redis_url,
        '--debug'
    end
  end

  def start_resque_workers
    @subscriber_queues.each do |queue|
      @pids << fork do
        ENV['CHASQUI_ENV'] = 'test'
        ENV['QUEUE'] = queue
        ENV['TERM_CHILD'] = '1'
        ENV['INTERVAL'] = '1'
        ENV['REDIS_NAMESPACE'] = "resque:#{queue}"
        ENV['REDIS_URL'] = @redis_url
        exec 'bundle', 'exec', 'rake', 'resque:work'
      end
    end
  end

  def terminate_child_processes
    Timeout::timeout(10) do
      @pids.each { |pid| kill 'TERM', pid rescue nil }
    end
  rescue TimeoutError
    @pids.each { |pid| kill 'KILL', pid rescue nil }
    fail "One or more child processes failed to terminate in a timely manner"
  end

  def kill(signal, pid)
    Process.kill signal, pid
    unless signal == 'KILL'
      pid, status = Process.waitpid2 pid, 0
      expect(status.exitstatus).to eq(0)
    end
  end

end
