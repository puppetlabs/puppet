# Returns a new instance of a data type.
# (The documentation is maintained in the corresponding 3.x stub)
#
# @since 4.5.0
#
Puppet::Functions.create_function(:new, Puppet::Functions::InternalFunction) do

  dispatch :new_instance do
    scope_param
    param          'Type', :type
    repeated_param 'Any',  :args
    optional_block_param
  end

  def new_instance(scope, t, *args)
    return args[0] if args.size == 1 && !t.is_a?(Puppet::Pops::Types::PInitType) && t.instance?(args[0])
    result = catch :undefined_value do
      new_function_for_type(t, scope).call(scope, *args)
    end
    assert_type(t, result)
    return block_given? ? yield(result) : result
  end

  def new_function_for_type(t, scope)
    @new_function_cache ||= Hash.new() {|hsh, key| hsh[key] = key.new_function.new(scope, loader) }
    @new_function_cache[t]
  end

  def assert_type(type, value)
    Puppet::Pops::Types::TypeAsserter.assert_instance_of(['Converted value from %s.new()', type], type, value)
  end
end
