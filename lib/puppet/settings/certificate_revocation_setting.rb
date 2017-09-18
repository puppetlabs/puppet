require 'puppet/settings/base_setting'

class Puppet::Settings::CertificateRevocationSetting < Puppet::Settings::BaseSetting

  def type
    :certificate_revocation
  end

  def munge(value)
    case value
    when 'chain', 'true', TrueClass
      :chain
    when 'leaf'
      :leaf
    when 'false', FalseClass, NilClass
      false
    else
      raise Puppet::Settings::ValidationError, _("Invalid certificate revocation value %{value}: must be one of 'true', 'chain', 'leaf', or 'false'") % { value: value }
    end
  end
end
