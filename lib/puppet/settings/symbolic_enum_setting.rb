class Puppet::Settings::SymbolicEnumSetting < Puppet::Settings::BaseSetting
  attr_accessor :values

  def type
    :symbolic_enum
  end

  def munge(value)
    sym = value.to_sym
    if values.include?(sym)
      sym
    else
      raise Puppet::Settings::ValidationError,
        "Invalid value '#{value}' for parameter #{@name}. Allowed values are '#{values.join("', '")}'"
    end
  end
end
