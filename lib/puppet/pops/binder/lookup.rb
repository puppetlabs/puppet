# This class is the backing implementation of the Puppet function 'lookup'.
# See puppet/functions/lookup.rb for documentation.
#
class Puppet::Pops::Binder::Lookup
  # Performs a lookup in the configured scopes and optionally merges the default.
  #
  # This is a backing function and all parameters are assumed to have been type checked.
  # See puppet/functions/lookup.rb for full documentation and all parameter combinations.
  #
  # @param scope [Puppet::Parser::Scope] The scope to use for the lookup
  # @param name [String|Array<String>] The name or names to lookup
  # @param type [String|Puppet::Pops::Types::PAnyType] The expected type of the found value. Can be nil
  # @param default_value [Object] The value to use as default when no value is found
  # @param accept_undef [Boolean] true if it's accepable to return nil when no value is found. Can be nil
  # @param override [Hash<String,Object>] A map to use as override. Values found here are returned immediately. Can be empty.
  # @param extra [Hash<String,Object>] A map to use as the last resort (but before default). Can be empty.
  # @param merge [String|Hash<String,Object>] Merge strategy or hash with strategy and options
  # @return [Object] The found value
  #
  def self.lookup(scope, name, value_type, default_value, accept_undef, override, extra, merge)
    value_type = Puppet::Pops::Types::TypeParser.new.parse(value_type || 'Data') unless value_type.is_a?(Puppet::Pops::Types::PAnyType)
    names = name.is_a?(Array) ? name : [name]

    # find first name that yields a non-nil result and wrap it in a two element array
    # with name and value.
    result_with_name = names.reduce([nil,nil]) do |memo,key|
      value = assert_type('override', value_type, override[key])
      value = search_and_merge(key, value_type, scope, merge) if value.nil?
      memo = [ key, value ]
      break memo unless value.nil?
      memo
    end

    # Use the 'extra' map as a last resort if nothing is found
    if result_with_name[1].nil? && !extra.empty?
      result_with_name = names.reduce(result_with_name) do |memo,key|
        value = assert_type('extra', value_type, extra[key])
        memo = [ key, value ]
        break memo unless value.nil?
        memo
      end
    end

    answer = result_with_name[1]
    if answer.nil?
      if block_given?
        answer = assert_type('default_block', value_type, yield(name))
      else
        answer = assert_type('default_value', value_type, default_value)
      end
      fail_lookup(names) if answer.nil? && !accept_undef
    end
    answer
  end

  def self.search_and_merge(name, type, scope, merge)
    in_global = lambda { lookup_with_databinding(name, type, scope) }
    in_env = lambda { Puppet::DataProviders.lookup_in_environment(name, scope, merge) }
    in_module = lambda { Puppet::DataProviders.lookup_in_module(name, scope, merge) }

    [in_global, in_env, in_module].reduce(nil) do |memo, f|
      answer = f.call
      next memo if answer.nil? # nothing found, continue with next
      break answer if merge.nil? # answer found and no merge
      next answer if memo.nil?
      Puppet::Pops::MergeStrategy.merge(memo, answer, merge)
    end
  end
  private_class_method :search_and_merge

  def self.lookup_with_databinding(name, type, scope)
    begin
      Puppet::DataBinding.indirection.find(name, { :environment => scope.environment.to_s, :variables => scope })
    rescue Puppet::DataBinding::LookupError => e
      raise Puppet::Error, "Error from DataBinding '#{Puppet[:data_binding_terminus]}' while looking up '#{name}': #{e.message}", e
    end
  end
  private_class_method :lookup_with_databinding

  def self.assert_type(subject, type, value)
    Puppet::Pops::Types::TypeAsserter.assert_instance_of(subject, type, value, true)
  end
  private_class_method :assert_type

  def self.fail_lookup(names)
    name_part = names.size == 1 ? "the name '#{names[0]}'" : 'any of the names [' + names.map {|n| "'#{n}'"} .join(', ') + ']'
    raise Puppet::ParseError, "Function lookup() did not find a value for #{name_part}"
  end
  private_class_method :fail_lookup
end
