# Scans a string and returns an array of one or more converted values based on the given format string.
# See the documenation of Ruby's String#scanf method for details about the supported formats (which
# are similar but not identical to the formats used in Puppet's `sprintf` function.)
#
# This function takes two mandatory arguments: the first is the string to convert, and the second is
# the format string. The result of the scan is an array, with each sucessfully scanned and transformed value.
# The scanning stops if a scan is unsuccesful, and the scanned result up to that point is returned. If there
# was no succesful scan, the result is an empty array.
#
#    "42".scanf("%i")
#
# You can also optionally pass a lambda to scanf, to do additional validation or processing.
#
#
#     "42".scanf("%i") |$x| {
#       unless $x[0] =~ Integer {
#         fail "Expected a well formed integer value, got '$x[0]'"
#       }
#       $x[0]
#     }
#
#
#
#
#
# @since 4.0.0
#
Puppet::Functions.create_function(:scanf) do
  require 'scanf'

  dispatch :scanf do
    param 'String', :data
    param 'String', :format
    optional_block_param
  end

  def scanf(data, format)
    result = data.scanf(format)
    if block_given?
      result = yield(result)
    end
    result
  end
end
