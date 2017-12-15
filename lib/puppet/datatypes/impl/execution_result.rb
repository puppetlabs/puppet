module Puppet::DataTypes
class ExecutionResult
  include Puppet::Pops::Types::Iterable
  include Puppet::Pops::Types::IteratorProducer

  # Creates a pure Data hash from a result hash returned from the Bolt::Executor
  # @return [Hash{String => Data}] The data hash
  def self.from_bolt(result_hash)
    data_result = {}
    result_hash.each_pair { |k, v| data_result[k.uri] = v.to_h }
    self.new(data_result)
  end

  attr_reader :result_hash

  def initialize(result_hash, final=false)
    result_hash = convert_errors(result_hash) unless final
    @result_hash = result_hash
  end

  def count
    @result_hash.size
  end

  def empty
    @result_hash.empty?
  end
  alias_method :empty?, :empty

  def error_nodes
    result = {}
    @result_hash.each_pair { |k, v| result[k] = v if v.is_a?(Error) }
    self.class.new(result, true)
  end

  def iterator
    tc = Puppet::Pops::Types::TypeFactory
    Puppet::Pops::Types::Iterable.on(@result_hash, tc.tuple([tc.string, tc.data], Puppet::Pops::Types::PHashType::KEY_PAIR_TUPLE_SIZE))
  end

  def names
    @result_hash.keys
  end

  def ok
    !@result_hash.values.any? { |v| v.is_a?(Error) }
  end
  alias_method :ok?, :ok

  def ok_nodes
    result = {}
    @result_hash.each_pair { |k, v| result[k] = v unless v.is_a?(Error) }
    self.class.new(result, true)
  end

  def [](node_uri)
    @result_hash[node_uri]
  end

  def value(node_uri)
    self[node_uri]
  end

  def values
    @result_hash.values
  end

  def _pcore_init_hash
    @result_hash
  end

  def eql?(o)
    self.class == o.class && self.result_hash == o.result_hash
  end

  def ==(o)
    eql?(o)
  end

  def to_s
    # Use Puppet::Pops::Types::StringConverter if it is available
    if Object.const_defined?(:Puppet) && Puppet.const_defined?(:Pops)
      Puppet::Pops::Types::StringConverter.singleton.convert(self)
    else
      super
    end
  end

  private

  def convert_errors(result_hash)
    converted = {}
    result_hash.each_pair { |k, v| converted[k] = convert_error(v) }
    converted
  end

  def convert_error(value_or_error)
    error = value_or_error['error']
    value = value_or_error['value']
    error.nil? ? value : Error.new(error['msg'], error['kind'], error['issue_code'], value, error['details'])
  end
end
end