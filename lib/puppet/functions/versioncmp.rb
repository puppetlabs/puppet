require 'puppet/util/package'

# Compares two version numbers.
#
# Prototype:
#
#     \$result = versioncmp(a, b)
#
# Where a and b are arbitrary version strings.
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
  end

  def versioncmp(a, b)
    Puppet::Util::Package.versioncmp(a, b)
  end
end
