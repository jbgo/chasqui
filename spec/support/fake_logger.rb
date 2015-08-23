class FakeLogger
  attr_accessor :progname
  def info(*args, &block)
  end
end
