require 'puppet/confine'

# Require a specific value for a variable, either a Puppet setting
# or a Facter value.  This class is a bit weird because the name
# is set explicitly by the ConfineCollection class -- from this class,
# it's not obvious how the name would ever get set.
class Puppet::Confine::Variable < Puppet::Confine
  # Provide a hash summary of failing confines -- the key of the hash
  # is the name of the confine, and the value is the missing yet required values.
  # Only returns failed values, not all required values.
  def self.summarize(confines)
    result = Hash.new { |hash, key| hash[key] = [] }
    confines.inject(result) { |total, confine| total[confine.name] += confine.values unless confine.valid?; total }
  end

  # This is set by ConfineCollection.
  attr_accessor :name

  # Retrieve the value from facter
  def facter_value
    @facter_value ||= ::Facter.value(name).to_s.downcase
  end

  def initialize(values)
    super
    @values = @values.collect { |v| v.to_s.downcase }
  end

  def message(value)
    "facter value '#{test_value}' for '#{self.name}' not in required list '#{values.join(",")}'"
  end

  # Compare the passed-in value to the retrieved value.
  def pass?(value)
    test_value.downcase.to_s == value.to_s.downcase
  end

  def reset
    # Reset the cache.  We want to cache it during a given
    # run, but not across runs.
    @facter_value = nil
  end

  def valid?
    @values.include?(test_value.to_s.downcase)
  ensure
    reset
  end

  private

  def setting?
    Puppet.settings.valid?(name)
  end

  def test_value
    setting? ? Puppet.settings[name] : facter_value
  end
end
