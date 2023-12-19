# frozen_string_literal: true

require_relative '../../puppet/util/package'

# Compares two version numbers.
#
# Prototype:
#
#     $result = versioncmp(a, b)
#
# Where a and b are arbitrary version strings.
#
# Optional parameter ignore_trailing_zeroes is used to ignore unnecessary
# trailing version numbers like .0 or .0.00
#
# This function returns:
#
# * `1` if version a is greater than version b
# * `0` if the versions are equal
# * `-1` if version a is less than version b
#
# @example Using versioncmp
#
#     if versioncmp('2.6-1', '2.4.5') > 0 {
#         notice('2.6-1 is > than 2.4.5')
#     }
#
# This function uses the same version comparison algorithm used by Puppet's
# `package` type.
#
Puppet::Functions.create_function(:versioncmp) do
  dispatch :versioncmp do
    param 'String', :a
    param 'String', :b
    optional_param 'Boolean', :ignore_trailing_zeroes
  end

  def versioncmp(a, b, ignore_trailing_zeroes = false)
    Puppet::Util::Package.versioncmp(a, b, ignore_trailing_zeroes)
  end
end
