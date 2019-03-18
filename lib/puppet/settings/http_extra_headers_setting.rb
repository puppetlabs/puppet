class Puppet::Settings::HttpExtraHeadersSetting < Puppet::Settings::ArraySetting

  def type
    :http_extra_headers
  end

  def munge(value)
    headers = super
    headers.map! { |header|
      case header
      when String
        header.split(':')
      when Array
        header
      else
        raise ArgumentError, _("Expected an Array of String, got a %{klass}") % { klass: value.class }
      end
    }
  end
end
