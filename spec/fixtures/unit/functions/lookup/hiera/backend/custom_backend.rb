class Hiera::Backend::Custom_backend
  def lookup(key, scope, order_override, resolution_type, context)
    case key
    when 'hash_c'
      { 'hash_ca' => { 'cad' => 'value hash_c.hash_ca.cad (from global custom)' }}
    when 'hash'
      { 'array' => [ 'x5,x6' ] }
    when 'array'
      [ 'x5,x6' ]
    when 'datasources'
      Hiera::Backend.datasources(scope, order_override) { |source| source }
    when 'dotted.key'
      'custom backend received request for dotted.key value'
    else
      throw :no_such_key
    end
  end
end
