# (Documentation in 3.x stub)
#
# @since 4.7.0
#
Puppet::Functions.create_function(:strftime) do
  dispatch :format do
    param 'Variant[Timestamp,Timespan]', :time_object
    param 'String', :format
  end

  def format(time_object, format)
    time_object.format(format)
  end
end
