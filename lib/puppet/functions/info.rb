# Logs a message on the server at level `info`.
Puppet::Functions.create_function(:info, Puppet::Functions::InternalFunction) do
  # @param values The values to log.
  # @return [Undef]
  dispatch :info do
    scope_param
    repeated_param 'Any', :values
    return_type 'Undef'
  end

  def info(scope, *values)
    Puppet::Util::Log.log_func(scope, :info, values)
  end
end
