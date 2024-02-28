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

    while ax.length > 0 && bx.length > 0
      a = ax.shift
      b = bx.shift

      next      if a == b
      return -1 if a == '-'
      return 1  if b == '-'
      return -1 if a == '.'
      return 1  if b == '.'

      if a =~ /^\d+$/ && b =~ /^\d+$/
        return a.to_s.upcase <=> b.to_s.upcase if a =~ /^0/ || b =~ /^0/

        return a.to_i <=> b.to_i
      end
      return a.upcase <=> b.upcase
    end
    version_a <=> version_b
  end
  module_function :versioncmp

  def self.normalize(version)
    version = version.split('-')
    version.first.sub!(/([\.0]+)$/, '')

    version.join('-')
  end
  private_class_method :normalize
end
