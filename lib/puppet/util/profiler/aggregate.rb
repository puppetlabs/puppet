require 'puppet/util/profiler'
require 'puppet/util/profiler/wall_clock'

class Puppet::Util::Profiler::Aggregate < Puppet::Util::Profiler::WallClock
  def initialize(logger, identifier)
    super(logger, identifier)
    @metrics_hash = Metric.new
  end

  def shutdown()
    super
    @logger.call("AGGREGATE PROFILING RESULTS:")
    @logger.call("----------------------------")
    print_metrics(@metrics_hash, "")
    @logger.call("----------------------------")
  end

  def do_start(description, metric_id)
    super(description, metric_id)
  end

  def do_finish(context, description, metric_id)
    result = super(context, description, metric_id)
    update_metric(@metrics_hash, metric_id, result[:time])
    result
  end

  def update_metric(metrics_hash, metric_id, time)
    first, *rest = *metric_id
    if first
      m = metrics_hash[first]
      m.increment
      m.add_time(time)
      if rest.count > 0
        update_metric(m, rest, time)
      end
    end
  end

  def values
    @metrics_hash
  end

  def print_metrics(metrics_hash, prefix)
    metrics_hash.sort_by {|k,v| v.time }.reverse.each do |k,v|
      @logger.call("#{prefix}#{k}: #{v.time} s (#{v.count} calls)")
      print_metrics(metrics_hash[k], "#{prefix}#{k} -> ")
    end
  end

  class Metric < Hash
    def initialize
      super
      @count = 0
      @time = 0
    end
    attr_reader :count, :time

    def [](key)
      if !has_key?(key)
        self[key] = Metric.new
      end
      super(key)
    end

    def increment
      @count += 1
    end

    def add_time(time)
      @time += time
    end
  end

  class Timer
    def initialize
      @start = Time.now
    end

    def stop
      Time.now - @start
    end
  end
end

