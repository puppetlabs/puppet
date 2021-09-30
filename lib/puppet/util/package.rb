# frozen_string_literal: true
module Puppet::Util::Package
  def versioncmp(version_a, version_b, ignore_trailing_zeroes = false)
    vre = /[-.]|\d+|[^-.\d]+/

    if ignore_trailing_zeroes
      version_a = normalize(version_a)
      version_b = normalize(version_b)
    end

    ax = version_a.scan(vre)
    bx = version_b.scan(vre)

    while (ax.length>0 && bx.length>0)
      a = ax.shift
      b = bx.shift

      if( a == b )                 then next
      elsif (a == '-' && b == '-') then next
      elsif (a == '-')             then return -1
      elsif (b == '-')             then return 1
      elsif (a == '.' && b == '.') then next
      elsif (a == '.' )            then return -1
      elsif (b == '.' )            then return 1
      elsif (a =~ /^\d+$/ && b =~ /^\d+$/) then
        if( a =~ /^0/ or b =~ /^0/ ) then
          return a.to_s.upcase <=> b.to_s.upcase
        end
        return a.to_i <=> b.to_i
      else
        return a.upcase <=> b.upcase
      end
    end
    version_a <=> version_b;
  end
  module_function :versioncmp

  def self.normalize(version)
    version = version.split('-')
    version.first.sub!(/([\.0]+)$/, '')

    version.join('-')
  end
  private_class_method :normalize
end
