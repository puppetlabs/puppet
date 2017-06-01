require 'puppet/parameter'

# This specialized {Puppet::Parameter} handles munging of package options.
# Package options are passed as an array of key value pairs. Special munging is
# required as the keys and values needs to be quoted in a safe way.
#
class Puppet::Parameter::PackageOptions < Puppet::Parameter
  def unsafe_munge(values)
    values = [values] unless values.is_a? Array

    values.collect do |val|
      case val
      when Hash
        safe_hash = {}
        val.each_pair do |k, v|
          safe_hash[quote(k)] = quote(v)
        end
        safe_hash
      when String
        quote(val)
      else
        fail(_("Expected either a string or hash of options"))
      end
    end
  end

  # @api private
  def quote(value)
    value.include?(' ') ? %Q["#{value.gsub(/"/, '\"')}"] : value
  end
end
