require 'puppet/parameter'

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
        fail("Expected either a string or hash of options")
      end
    end
  end

  def quote(value)
    value.include?(' ') ? %Q["#{value.gsub(/"/, '\"')}"] : value
  end
end
