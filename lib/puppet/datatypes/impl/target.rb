class Puppet::DataTypes::Target
  attr_reader :host, :options

  def self.from_asserted_hash(hash)
    new(hash['host'], hash['options'])
  end

  def initialize(host, options = {})
    @host = host
    @options = options
  end

  def eql?(o)
    self.class.equal?(o.class) && @host == o.host && @options == o.options
  end
  alias == eql?

  def hash
    @host.hash ^ @options.hash
  end

  def to_s
    # Use Puppet::Pops::Types::StringConverter if it is available
    if Object.const_defined?(:Puppet) && Puppet.const_defined?(:Pops)
      Puppet::Pops::Types::StringConverter.singleton.convert(self)
    else
      super
    end
  end
end
