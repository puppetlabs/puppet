require 'puppet/util/profiler/logging'

class Puppet::Util::Profiler::ObjectCounts < Puppet::Util::Profiler::Logging
  def start
    ObjectSpace.count_objects
  end

  def finish(before)
    after = ObjectSpace.count_objects

    diff = before.collect do |type, count|
      [type, after[type] - count]
    end

    diff.sort.collect { |pair| pair.join(': ') }.join(', ')
  end
end
