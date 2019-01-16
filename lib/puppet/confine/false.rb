require 'puppet/confine/boolean'

class Puppet::Confine::False < Puppet::Confine
  include Puppet::Confine::Boolean

  def passing_value
    false
  end

  def self.summarize(confines)
    confines.inject(0) { |count, confine| count + confine.summary }
  end

  def pass?(value)
    ! value
  end

  def message(value)
    "true value when expecting false"
  end

  def summary
    result.find_all { |v| v == false }.length
  end
end
