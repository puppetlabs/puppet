# This specialized {Puppet::Parameter} handles boolean options, accepting lots
# of strings and symbols for both truthiness and falsehood.
#
class Puppet::Parameter::Boolean < Puppet::Parameter
  def unsafe_munge(value)
    # downcase strings
    if value.respond_to? :downcase
      value = value.downcase
    end

    case value
    when true, :true, 'true', :yes, 'yes'
      true
    when false, :false, 'false', :no, 'no'
      false
    else
      fail('expected a boolean value')
    end
  end
end
