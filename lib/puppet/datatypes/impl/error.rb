class Puppet::DataTypes::Error
  attr_reader :message, :kind, :issue_code, :partial_result, :details

  def self.from_asserted_hash(hash)
    new(hash['message'], hash['kind'], hash['issue_code'], hash['partial_result'], hash['details'])
  end

  def _pcore_init_hash
    result = { 'message' => @message }
    result['kind'] = @kind unless @kind.nil?
    result['issue_code'] = @issue_code unless @issue_code.nil?
    result['partial_result'] = @partial_result unless @partial_result.nil?
    result['details'] = @details unless @details.nil?
    result
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
    Puppet::Pops::Types::StringConverter.singleton.convert(self)
  end
end
