# Logs a message on the server at level `notice`.
Puppet::Functions.create_function(:notice, Puppet::Functions::InternalFunction) do
  # @param values The values to log.
  # @return [Undef]
  dispatch :notice do
    scope_param
    repeated_param 'Any', :values
    return_type 'Undef'
  end

  def notice(scope, *values)
    Puppet::Util::Log.log_func(scope, :notice, values)
  end
end
