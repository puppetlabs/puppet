# This provides ProcessStatus Output specific overrides
#  to string to give things back like exitstatus.
# @api private
class Puppet::ProcessOutput < String
  attr_reader :exitstatus
  def initialize(value,exitstatus)
    super(value)
    @exitstatus = exitstatus
  end
end
