# Logs a message on the server at level `alert`.
Puppet::Functions.create_function(:alert, Puppet::Functions::InternalFunction) do
  # @param values The values to log.
  # @return [Undef]
  dispatch :alert do
    scope_param
    repeated_param 'Any', :values
    return_type 'Undef'
  end

  def alert(scope, *values)
    Puppet::Util::Log.log_func(scope, :alert, values)
  end
end
