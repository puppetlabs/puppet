Puppet::Util::Instrumentation.new_listener(:performance) do

  attr_reader :samples

  def initialize
    @samples = {}
  end

  def notify(label, event, data)
    return if event == :start

    duration = data[:finished] - data[:started]
    @samples[label] ||= { :count => 0, :max => 0, :min => nil, :sum => 0, :average => 0 }
    @samples[label][:count] += 1
    @samples[label][:sum] += duration
    @samples[label][:max] = [ @samples[label][:max], duration ].max
    @samples[label][:min] = [ @samples[label][:min], duration ].reject { |val| val.nil? }.min
    @samples[label][:average] = @samples[label][:sum] / @samples[label][:count]
  end

  def data
    @samples.dup
  end
end
