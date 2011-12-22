require 'monitor'

Puppet::Util::Instrumentation.new_listener(:performance) do

  attr_reader :samples

  def initialize
    @samples = {}.extend(MonitorMixin)
  end

  def notify(label, event, data)
    return if event == :start

    duration = data[:finished] - data[:started]
    samples.synchronize do
      @samples[label] ||= { :count => 0, :max => 0, :min => nil, :sum => 0, :average => 0 }
      @samples[label][:count] += 1
      @samples[label][:sum] += duration
      @samples[label][:max] = [ @samples[label][:max], duration ].max
      @samples[label][:min] = [ @samples[label][:min], duration ].reject { |val| val.nil? }.min
      @samples[label][:average] = @samples[label][:sum] / @samples[label][:count]
    end
  end

  def data
    samples.synchronize do
      @samples.dup
    end
  end
end