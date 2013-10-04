# A simple boolean.
class Puppet::Settings::BooleanSetting < Puppet::Settings::BaseSetting
  # get the arguments in getopt format
  def getopt_args
    if short
      [["--#{name}", "-#{short}", GetoptLong::NO_ARGUMENT], ["--no-#{name}", GetoptLong::NO_ARGUMENT]]
    else
      [["--#{name}", GetoptLong::NO_ARGUMENT], ["--no-#{name}", GetoptLong::NO_ARGUMENT]]
    end
  end

  def optparse_args
    if short
      ["--[no-]#{name}", "-#{short}", desc, :NONE ]
    else
      ["--[no-]#{name}", desc, :NONE]
    end
  end

  def munge(value)
    case value
    when true, "true"; return true
    when false, "false"; return false
    else
      raise Puppet::Settings::ValidationError, "Invalid value '#{value.inspect}' for boolean parameter: #{@name}"
    end
  end

  def type
    :boolean
  end
end
