require 'puppet/confine'

class Puppet::Confine::True < Puppet::Confine
  def self.summarize(confines)
    confines.inject(0) { |count, confine| count + confine.summary }
  end

  def pass?(value)
    # Double negate, so we only get true or false.
    ! ! value
  end

  def message(value)
    "false value when expecting true"
  end

  def summary
    result.find_all { |v| v == true }.length
  end
end
