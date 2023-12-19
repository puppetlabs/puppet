# frozen_string_literal: true

class Puppet::Settings::HttpExtraHeadersSetting < Puppet::Settings::BaseSetting
  def type
    :http_extra_headers
  end

  def munge(headers)
    return headers if headers.is_a?(Hash)

    headers = headers.split(/\s*,\s*/) if headers.is_a?(String)

    raise ArgumentError, _("Expected an Array, String, or Hash, got a %{klass}") % { klass: headers.class } unless headers.is_a?(Array)

    headers.map! { |header|
      case header
      when String
        header.split(':')
      when Array
        header
      else
        raise ArgumentError, _("Expected an Array or String, got a %{klass}") % { klass: header.class }
      end
    }
  end
end
