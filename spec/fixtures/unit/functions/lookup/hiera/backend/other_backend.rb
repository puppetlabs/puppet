class Hiera::Backend::Other_backend
  def lookup(key, scope, order_override, resolution_type, context)
    value = Hiera::Config[:other][key.to_sym]
    throw :no_such_key if value.nil?
    value
  end
end
