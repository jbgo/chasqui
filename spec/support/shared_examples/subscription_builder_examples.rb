shared_examples 'a subscription builder' do |worker|
  before { reset_chasqui_workers }

  # hook for any backend specific assertions on the generated worker class
  # for a proc
  def expect_worker_to_support_backend(worker)
    # noop
  end

  describe '#on' do
    let(:channel) { 'busy.channel' }
    let(:queue) { 'pubsub' }

    let(:subscriptions) { double }

    let(:builder) { described_class.new subscriptions }

    it 'subscribes the worker to the channel' do
      expect(subscriptions).to receive(:register) do |subscriber|
        expect(subscriber.channel).to eq(channel)
        expect(subscriber.worker).to eq(worker)
        expect(subscriber.queue).to eq(queue)
      end

      builder.on channel, worker
    end

    it 'prefixes the queue name' do
      full_queue_name = "app_id:#{queue}"

      expect(subscriptions).to receive(:register) do |subscriber|
        expect(subscriber.channel).to eq(channel)
        expect(subscriber.worker).to eq(worker)
        expect(subscriber.queue).to eq(full_queue_name)
      end

      builder.on channel, worker, queue_name_prefix: 'app_id'

      expect(queue_name(worker)).to eq(full_queue_name)
    end

    it 'uses a different queue' do
      expect(subscriptions).to receive(:register) do |subscriber|
        expect(subscriber.channel).to eq(channel)
        expect(subscriber.worker).to eq(worker)
        expect(subscriber.queue).to eq('other:queue')
      end

      builder.on channel, worker, queue: 'other:queue'

      expect(queue_name(worker)).to eq('other:queue')
    end

    it 'does something expected when both options are used' do
      expect(subscriptions).to receive(:register) do |subscriber|
        expect(subscriber.channel).to eq(channel)
        expect(subscriber.worker).to eq(worker)
        expect(subscriber.queue).to eq('prefix:other:queue')
      end

      builder.on channel, worker, queue: 'other:queue', queue_name_prefix: 'prefix'

      expect(queue_name(worker)).to eq('prefix:other:queue')
    end

    it 'converts a proc to a worker' do
      expect(subscriptions).to receive(:register) do |subscriber|
        queue = "app_id:#{Chasqui.default_queue}"

        expect(subscriber.channel).to eq('busy.channel')
        expect(subscriber.queue).to eq(queue)

        worker = subscriber.worker
        expect(worker.name).to eq('Chasqui::Workers::BusyChannelWorker')
        expect(queue_name(worker)).to eq(queue)

        expect(perform(worker, 3)).to eq(6)
        expect_worker_to_support_backend(worker)
      end

      builder.on channel, ->(x) { x + x }, queue_name_prefix: 'app_id'
    end

    context 'default options' do
      let(:builder) do
        described_class.new subscriptions, queue_name_prefix: 'unique', queue: 'low-priority'
      end

      it 'uses options supplied during initialization when not supplied to #on' do
        expect(subscriptions).to receive(:register) do |subscriber|
          expect(subscriber.queue).to eq('unique:high-priority')
        end

        builder.on channel, worker, queue: 'high-priority'
      end
    end
  end
end
