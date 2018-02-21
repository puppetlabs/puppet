# Logs a message on the server at level `notice`.
Puppet::Functions.create_function(:warning, Puppet::Functions::InternalFunction) do
  # @param values The values to log.
  # @return [Undef]
  dispatch :warning do
    scope_param
    repeated_param 'Any', :values
    return_type 'Undef'
  end

  def warning(scope, *values)
    Puppet::Util::Log.log_func(scope, :warning, values)
  end
end
