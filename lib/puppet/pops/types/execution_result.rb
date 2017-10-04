module Puppet::Pops
module Types
  class ExecutionResult
    include PuppetObject
    include Iterable
    include IteratorProducer

    TYPE_RESULT_HASH = TypeFactory.hash_kv(PStringType::NON_EMPTY, TypeFactory.struct({
      TypeFactory.optional('value') => TypeFactory.data,
      TypeFactory.optional('error') => TypeFactory.struct({
        'message' => PStringType::NON_EMPTY,
        TypeFactory.optional('kind') => PStringType::NON_EMPTY,
        TypeFactory.optional('issue_code') => PStringType::NON_EMPTY,
        TypeFactory.optional('details') => TypeFactory.hash_of_data,
      })
    }))

    TYPE_RESULT_ERRORS = TypeFactory.hash_kv(PStringType::NON_EMPTY, TypeFactory.variant(TypeFactory.error, TypeFactory.data))

    def self.register_ptype(loader, ir)
      @type = Pcore::create_object_type(loader, ir, self, 'ExecutionResult', nil,
        { 'result_hash' => TYPE_RESULT_HASH },
        {
          'count' => TypeFactory.callable([], TypeFactory.integer),
          'empty' => TypeFactory.callable([], TypeFactory.boolean),
          'error_nodes' => TypeFactory.callable([], TypeFactory.type_reference('ExecutionResult')),
          'names' => TypeFactory.callable([], TypeFactory.array_of(PStringType::NON_EMPTY)),
          'ok' => TypeFactory.callable([], TypeFactory.boolean),
          'ok_nodes' => TypeFactory.callable([], TypeFactory.type_reference('ExecutionResult')),
          'value' => TypeFactory.callable([PStringType::NON_EMPTY], TypeFactory.variant(TypeFactory.error, TypeFactory.data)),
          'values' => TypeFactory.callable([], TypeFactory.array_of(TypeFactory.variant(TypeFactory.error, TypeFactory.data))),
        })
    end

    def self._pcore_type
      @type
    end

    attr_reader :result_hash

    def initialize(result_hash)
      @result_hash = convert_errors(result_hash)
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
      @result_hash.each_pair { |k, v| result[k] = v if v.is_a?(PErrorType::Error) }
      self.class.new(result)
    end

    def iterator
      Iterable.on(@result_hash)
    end

    def names
      @result_hash.keys
    end

    def ok
      !@result_hash.values.any? { |v| v.is_a?(PErrorType::Error) }
    end
    alias_method :ok?, :ok

    def ok_nodes
      result = {}
      @result_hash.each_pair { |k, v| result[k] = v unless v.is_a?(PErrorType::Error) }
      self.class.new(result)
    end

    def value(node_uri)
      @result_hash[node_uri]
    end

    def values
      @result_hash.values
    end

    def _pcore_init_hash
      @result_hash
    end

    private

    def convert_errors(result_hash)
      return result_hash unless TYPE_RESULT_HASH.instance?(result_hash)
      converted = {}
      result_hash.each_pair { |k, v| converted[k] = convert_error(v) }
      converted
    end

    def convert_error(value_or_error)
      error = value_or_error['error']
      value = value_or_error['value']
      if error.nil?
        value
      else
        PErrorType::Error.new(error['message'], error['kind'], error['issue_code'] || PErrorType::DEFAULT_ISSUE_CODE, value, error['details'])
      end
    end
  end
end
end
