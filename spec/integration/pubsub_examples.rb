require 'spec_helper'

shared_examples 'pubsub' do |namespace, start_workers_method|

  def events_to_publish
    [
      { event: 'user.signup',    data: ['Kelly'] },
      { event: 'account.credit', data: [1337, 'Kelly'] },
      { event: 'account.debit',  data: [10, 'Kelly'] },
      { event: 'user.signup',    data: ['Travis'] },
      { event: 'account.debit',  data: [9000, 'Kelly'] },
      { event: 'user.cancel',    data: ['Kelly'] },
      { event: 'account.credit', data: [42, 'Travis'] },
    ]
  end

  def expected_events
    {
      'app1' => [
        { event: 'user.signup', data: ['Kelly'] },
        { event: 'user.signup', data: ['Travis'] },
      ],
      'app2' => [
        { event: 'account.credit', data: [1337, 'Kelly'] },
        { event: 'account.debit',  data: [10, 'Kelly'] },
        { event: 'account.debit',  data: [9000, 'Kelly'] },
        { event: 'user.cancel',    data: ['Kelly'] },
        { event: 'account.credit', data: [42, 'Travis'] },
      ],
    }
  end

  before do
    @subscriber_queues = %w(app1 app2)
    @redis_url = 'redis://localhost:6379/13'
    @redis = Redis.new url: @redis_url
    @redis.keys('*').each { |k| @redis.del k }

    Chasqui.configure do |c|
      c.channel = 'integration'
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
      Chasqui.publish event[:event], *event[:data]
    end

    begin
      Timeout::timeout(10) do
        expected_events.each do |subscriber_queue, events|
          events.each do |expected|
            _, payload = @redis.blpop "#{namespace}:#{subscriber_queue}:event_log"
            actual = JSON.parse payload
            expect(actual['event']).to eq(expected[:event])
            expect(actual['data']).to eq(expected[:data])
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
