# A no-op profiler. Used when there is no profiling wanted.
#
# @api private
class Puppet::Util::Profiler::None
  def profile(description, &block)
    yield
  end
end
