# Logs a message on the server at level `err`.
Puppet::Functions.create_function(:err, Puppet::Functions::InternalFunction) do
  # @param values The values to log.
  # @return [Undef]
  dispatch :err do
    scope_param
    repeated_param 'Any', :values
    return_type 'Undef'
  end

  def err(scope, *values)
    Puppet::Util::Log.log_func(scope, :err, values)
  end
end
