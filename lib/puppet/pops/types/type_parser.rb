# This class provides parsing of Type Specification from a string into the Type
# Model that is produced by the Puppet::Pops::Types::TypeFactory.
#
# The Type Specifications that are parsed are the same as the stringified forms
# of types produced by the Puppet::Pops::Types::TypeCalculator.
#
# @api private
class Puppet::Pops::Types::TypeParser
  def parse(string)
    types = Puppet::Pops::Types::TypeFactory
    case string
    when "Integer"
      types.integer
    when "Float"
      types.float
    when "String"
      types.string
    when "Boolean"
      types.boolean
    when "Pattern"
      types.pattern
    when "Data"
      types.data
    when "Object"
      types.object
    else
      raise Puppet::ParseError, "Unknown type <#{string}>"
    end
  end
end
