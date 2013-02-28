class Puppet::Util::Profiler::None
  def profile(description, &block)
    yield
  end
end
