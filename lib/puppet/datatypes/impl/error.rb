class Puppet::DataTypes::Error
  attr_reader :message, :kind, :issue_code, :partial_result, :details

  def self.from_asserted_hash(hash)
    new(hash['message'], hash['kind'], hash['issue_code'], hash['partial_result'], hash['details'])
  end

  def initialize(message, kind = nil, issue_code = nil, partial_result = nil, details = nil)
    @message = message
    @kind = kind
    @issue_code = issue_code
    @partial_result = partial_result
    @details = details
  end

  def eql?(o)
    self.class.equal?(o.class) &&
      @message == o.message &&
      @kind == o.kind &&
      @issue_code == o.issue_code &&
      @partial_result == o.partial_result &&
      @details == o.details
  end
  alias == eql?

  def hash
    @message.hash ^ @kind.hash ^ @issue_code.hash
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
