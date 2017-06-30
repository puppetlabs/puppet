class Puppet::Settings::TerminusSetting < Puppet::Settings::BaseSetting
  def munge(value)
    case value
    when '', nil
      nil
    when String
      value.intern
    when Symbol
      value
    else
      raise Puppet::Settings::ValidationError, _("Invalid terminus setting: %{value}") % { value: value }
    end
  end
end
