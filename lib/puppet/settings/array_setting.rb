class Puppet::Settings::ArraySetting < Puppet::Settings::BaseSetting

  def type
    :array
  end

  def munge(value)
    case value
    when String
      value.split(/\s*,\s*/)
    when Array
      value
    else
      raise ArgumentError, _("Expected an Array or String, got a %{klass}") % { klass: value.class }
    end
  end
end
