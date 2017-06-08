# (Documentation in 3.x stub)
#
# @since 4.8.0
#
Puppet::Functions.create_function(:strftime) do
  dispatch :format_timespan do
    param 'Timespan', :time_object
    param 'String', :format
  end

  dispatch :format_timestamp do
    param 'Timestamp', :time_object
    param 'String', :format
    optional_param 'String', :timezone
  end

  dispatch :legacy_strftime do
    param 'String', :format
    optional_param 'String', :timezone
  end

  def format_timespan(time_object, format)
    time_object.format(format)
  end

  def format_timestamp(time_object, format, timezone = nil)
    time_object.format(format, timezone)
  end

  def legacy_strftime(format, timezone = nil)
    stacktrace = Puppet::Pops::PuppetStack.stacktrace()
    if stacktrace.size > 0
      file, line = stacktrace[0]
    else
      file = nil
      line = nil
    end
    Puppet.warn_once('deprecations', 'legacy#strftime',
      _('The argument signature (String format, [String timezone]) is deprecated for #strfime. See #strftime documentation and Timespan type for more info'),
      file, line)
    Puppet::Pops::Time::Timestamp.format_time(format, Time.now.utc, timezone)
  end
end
