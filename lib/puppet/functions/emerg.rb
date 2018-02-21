# Logs a message on the server at level `emerg`.
Puppet::Functions.create_function(:emerg, Puppet::Functions::InternalFunction) do
  # @param values The values to log.
  # @return [Undef]
  dispatch :emerg do
    scope_param
    repeated_param 'Any', :values
    return_type 'Undef'
  end

  def emerg(scope, *values)
    Puppet::Util::Log.log_func(scope, :emerg, values)
  end
end
