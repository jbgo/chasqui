class Chasqui::ResqueWorker

  class << self
    def create(queue, subscriber)
      Class.new(self).tap do |worker|
        worker.instance_variable_set(:@queue, queue)
      end
    end
  end
end
