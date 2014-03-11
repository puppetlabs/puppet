class Puppet::Confine::Any < Puppet::Confine
  def self.summarize(confines)
    confines.inject(0) { |count, confine| count + confine.summary }
  end

  def pass?(value)
    !! value
  end

  def message(value)
    "0 confines (of #{value.length}) were true"
  end

  def summary
    result.find_all { |v| v == true }.length
  end

  def valid?
    if @values.any? { |value| pass?(value) }
      true
    else
      Puppet.debug("#{label}: #{message(@values)}")
      false
    end
  end
end
