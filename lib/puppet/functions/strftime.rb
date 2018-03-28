# Formats timestamp or timespan according to the directives in the given format string. The directives begins with a percent (%) character.
# Any text not listed as a directive will be passed through to the output string.
#
# A third optional timezone argument can be provided. The first argument will then be formatted to represent a local time in that
# timezone. The timezone can be any timezone that is recognized when using the '%z' or '%Z' formats, or the word 'current', in which
# case the current timezone of the evaluating process will be used. The timezone argument is case insensitive.
#
# The default timezone, when no argument is provided, or when using the keyword `default`, is 'UTC'.
#
# The directive consists of a percent (%) character, zero or more flags, optional minimum field width and
# a conversion specifier as follows:
#
# ```
# %[Flags][Width]Conversion
# ```
#
# ### Flags that controls padding
#
# | Flag  | Meaning
# | ----  | ---------------
# | -     | Don't pad numerical output
# | _     | Use spaces for padding
# | 0     | Use zeros for padding
#
# ### `Timestamp` specific flags
#
# | Flag  | Meaning
# | ----  | ---------------
# | #     | Change case
# | ^     | Use uppercase
# | :     | Use colons for %z
#
# ### Format directives applicable to `Timestamp` (names and padding can be altered using flags):
#
# **Date (Year, Month, Day):**
#
# | Format | Meaning |
# | ------ | ------- |
# | Y | Year with century, zero-padded to at least 4 digits |
# | C | year / 100 (rounded down such as 20 in 2009) |
# | y | year % 100 (00..99) |
# | m | Month of the year, zero-padded (01..12) |
# | B | The full month name ("January") |
# | b | The abbreviated month name ("Jan") |
# | h | Equivalent to %b |
# | d | Day of the month, zero-padded (01..31) |
# | e | Day of the month, blank-padded ( 1..31) |
# | j | Day of the year (001..366) |
#
# **Time (Hour, Minute, Second, Subsecond):**
#
# | Format | Meaning |
# | ------ | ------- |
# | H | Hour of the day, 24-hour clock, zero-padded (00..23) |
# | k | Hour of the day, 24-hour clock, blank-padded ( 0..23) |
# | I | Hour of the day, 12-hour clock, zero-padded (01..12) |
# | l | Hour of the day, 12-hour clock, blank-padded ( 1..12) |
# | P | Meridian indicator, lowercase ("am" or "pm") |
# | p | Meridian indicator, uppercase ("AM" or "PM") |
# | M | Minute of the hour (00..59) |
# | S | Second of the minute (00..60) |
# | L | Millisecond of the second (000..999). Digits under millisecond are truncated to not produce 1000 |
# | N | Fractional seconds digits, default is 9 digits (nanosecond). Digits under a specified width are truncated to avoid carry up |
#
# **Time (Hour, Minute, Second, Subsecond):**
#
# | Format | Meaning |
# | ------ | ------- |
# | z   | Time zone as hour and minute offset from UTC (e.g. +0900) |
# | :z  | hour and minute offset from UTC with a colon (e.g. +09:00) |
# | ::z | hour, minute and second offset from UTC (e.g. +09:00:00) |
# | Z   | Abbreviated time zone name or similar information.  (OS dependent) |
#
# **Weekday:**
#
# | Format | Meaning |
# | ------ | ------- |
# | A | The full weekday name ("Sunday") |
# | a | The abbreviated name ("Sun") |
# | u | Day of the week (Monday is 1, 1..7) |
# | w | Day of the week (Sunday is 0, 0..6) |
#
# **ISO 8601 week-based year and week number:**
#
# The first week of YYYY starts with a Monday and includes YYYY-01-04.
# The days in the year before the first week are in the last week of
# the previous year.
#
# | Format | Meaning |
# | ------ | ------- |
# | G | The week-based year |
# | g | The last 2 digits of the week-based year (00..99) |
# | V | Week number of the week-based year (01..53) |
#
# **Week number:**
#
# The first week of YYYY that starts with a Sunday or Monday (according to %U
# or %W). The days in the year before the first week are in week 0.
#
# | Format | Meaning |
# | ------ | ------- |
# | U | Week number of the year. The week starts with Sunday. (00..53) |
# | W | Week number of the year. The week starts with Monday. (00..53) |
#
# **Seconds since the Epoch:**
#
# | Format | Meaning |
# | s | Number of seconds since 1970-01-01 00:00:00 UTC. |
#
# **Literal string:**
#
# | Format | Meaning |
# | ------ | ------- |
# | n | Newline character (\n) |
# | t | Tab character (\t) |
# | % | Literal "%" character |
#
# **Combination:**
#
# | Format | Meaning |
# | ------ | ------- |
# | c | date and time (%a %b %e %T %Y) |
# | D | Date (%m/%d/%y) |
# | F | The ISO 8601 date format (%Y-%m-%d) |
# | v | VMS date (%e-%^b-%4Y) |
# | x | Same as %D |
# | X | Same as %T |
# | r | 12-hour time (%I:%M:%S %p) |
# | R | 24-hour time (%H:%M) |
# | T | 24-hour time (%H:%M:%S) |
#
# @example Using `strftime` with a `Timestamp`:
#
# ```puppet
# $timestamp = Timestamp('2016-08-24T12:13:14')
#
# # Notice the timestamp using a format that notices the ISO 8601 date format
# notice($timestamp.strftime('%F')) # outputs '2016-08-24'
#
# # Notice the timestamp using a format that notices weekday, month, day, time (as UTC), and year
# notice($timestamp.strftime('%c')) # outputs 'Wed Aug 24 12:13:14 2016'
#
# # Notice the timestamp using a specific timezone
# notice($timestamp.strftime('%F %T %z', 'PST')) # outputs '2016-08-24 04:13:14 -0800'
#
# # Notice the timestamp using timezone that is current for the evaluating process
# notice($timestamp.strftime('%F %T', 'current')) # outputs the timestamp using the timezone for the current process
# ```
#
# ### Format directives applicable to `Timespan`:
#
# | Format | Meaning |
# | ------ | ------- |
# | D | Number of Days |
# | H | Hour of the day, 24-hour clock |
# | M | Minute of the hour (00..59) |
# | S | Second of the minute (00..59) |
# | L | Millisecond of the second (000..999). Digits under millisecond are truncated to not produce 1000. |
# | N | Fractional seconds digits, default is 9 digits (nanosecond). Digits under a specified length are truncated to avoid carry up |
#
# The format directive that represents the highest magnitude in the format will be allowed to overflow.
# I.e. if no "%D" is used but a "%H" is present, then the hours will be more than 23 in case the
# timespan reflects more than a day.
#
# @example Using `strftime` with a Timespan and a format
#
# ```puppet
# $duration = Timespan({ hours => 3, minutes => 20, seconds => 30 })
#
# # Notice the duration using a format that outputs <hours>:<minutes>:<seconds>
# notice($duration.strftime('%H:%M:%S')) # outputs '03:20:30'
#
# # Notice the duration using a format that outputs <minutes>:<seconds>
# notice($duration.strftime('%M:%S')) # outputs '200:30'
# ```
#
# - Since 4.8.0
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
    file, line = Puppet::Pops::PuppetStack.top_of_stack
    Puppet.warn_once('deprecations', 'legacy#strftime',
      _('The argument signature (String format, [String timezone]) is deprecated for #strftime. See #strftime documentation and Timespan type for more info'),
      file, line)
    Puppet::Pops::Time::Timestamp.format_time(format, Time.now.utc, timezone)
  end
end
