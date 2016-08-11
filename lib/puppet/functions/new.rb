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
    result = catch :undefined_value do
      new_function_for_type(t, scope).call(scope, *args)
    end
    assert_type(t, result)
    return block_given? ? yield(result) : result
  end

  def new_function_for_type(t, scope)
    @new_function_cache ||= Hash.new() {|hsh, key| hsh[key] = key.new_function(loader).new(scope, loader) }
    @new_function_cache[t]
  end

  def assert_type(type, value)
    Puppet::Pops::Types::TypeAsserter.assert_instance_of('new():', type, value)
  end
end
