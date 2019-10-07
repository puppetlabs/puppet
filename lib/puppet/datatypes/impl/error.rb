class Puppet::DataTypes::Error
  attr_reader :msg, :kind, :issue_code, :details
  alias message msg

  def self.from_asserted_hash(hash)
    new(hash['msg'], hash['kind'], hash['details'], hash['issue_code'])
  end

  def _pcore_init_hash
    result = { 'msg' => @msg }
    result['kind'] = @kind unless @kind.nil?
    result['details'] = @details unless @details.nil?
    result['issue_code'] = @issue_code unless @issue_code.nil?
    result
  end

  def initialize(msg, kind = nil, details = nil, issue_code = nil)
    @msg = msg
    @kind = kind
    @details = details
    @issue_code = issue_code
  end

  def eql?(o)
    self.class.equal?(o.class) &&
      @msg == o.msg &&
      @kind == o.kind &&
      @issue_code == o.issue_code &&
      @details == o.details
  end
  alias == eql?

  def hash
    @msg.hash ^ @kind.hash ^ @issue_code.hash
  end

  def to_s
    Puppet::Pops::Types::StringConverter.singleton.convert(self)
  end
end
