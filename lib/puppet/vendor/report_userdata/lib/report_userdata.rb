require 'puppet/transaction'
require 'puppet/transaction/report'

module ReportExtensions
  # User specified data stored as a Hash.  The value must be serializable to
  # JSON.  The intent of this userdata is to allow end users to embed their own
  # data into the report for use with their own custom report processors.
  #
  # @return [Hash] userdata
  attr_accessor :userdata

  def initialize(*args)
    super(*args)
    @userdata = {}
  end
end

class Puppet::Transaction::Report
  prepend ReportExtensions
end
