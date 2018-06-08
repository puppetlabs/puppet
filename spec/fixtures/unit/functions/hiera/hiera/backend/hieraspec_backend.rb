class Hiera::Backend::Hieraspec_backend
  def initialize(cache = nil)
    Hiera.debug('Custom_backend starting')
  end

  def lookup(key, scope, order_override, resolution_type, context)
    case key
    when 'datasources'
      Hiera::Backend.datasources(scope, order_override) { |source| source }
    when 'resolution_type'
      if resolution_type == :hash
        { key => resolution_type.to_s }
      elsif resolution_type == :array
        [ key, resolution_type.to_s ]
      else
        "resolution_type=#{resolution_type}"
      end
    else
      throw :no_such_key
    end
  end
end
