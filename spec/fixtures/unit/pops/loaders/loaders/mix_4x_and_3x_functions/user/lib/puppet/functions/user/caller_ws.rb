Puppet::Functions.create_function(:'user::caller_ws', Puppet::Functions::InternalFunction) do
  dispatch :caller_ws do
    scope_param
    param 'String', :value
  end

  def caller_ws(scope, value)
    scope = scope.compiler.newscope(scope)
    scope['passed_in_scope'] = value
    call_function_with_scope(scope, 'callee_ws')
  end
end
