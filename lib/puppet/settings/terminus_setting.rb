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
      raise Puppet::Settings::ValidationError, "Invalid terminus setting: #{value}"
    end
  end
end
