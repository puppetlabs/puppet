# frozen_string_literal: true

# Splits a string into an array using a given pattern.
# The pattern can be a string, regexp or regexp type.
#
# @example Splitting a String value
#
# ```puppet
# $string     = 'v1.v2:v3.v4'
# $array_var1 = split($string, /:/)
# $array_var2 = split($string, '[.]')
# $array_var3 = split($string, Regexp['[.:]'])
#
# #`$array_var1` now holds the result `['v1.v2', 'v3.v4']`,
# # while `$array_var2` holds `['v1', 'v2:v3', 'v4']`, and
# # `$array_var3` holds `['v1', 'v2', 'v3', 'v4']`.
# ```
#
# Note that in the second example, we split on a literal string that contains
# a regexp meta-character (`.`), which must be escaped.  A simple
# way to do that for a single character is to enclose it in square
# brackets; a backslash will also escape a single character.
#
Puppet::Functions.create_function(:split) do
  dispatch :split_String do
    param 'String', :str
    param 'String', :pattern
  end

  dispatch :split_Regexp do
    param 'String', :str
    param 'Regexp', :pattern
  end

  dispatch :split_RegexpType do
    param 'String', :str
    param 'Type[Regexp]', :pattern
  end

  dispatch :split_String_sensitive do
    param 'Sensitive[String]', :sensitive
    param 'String', :pattern
  end

  dispatch :split_Regexp_sensitive do
    param 'Sensitive[String]', :sensitive
    param 'Regexp', :pattern
  end

  dispatch :split_RegexpType_sensitive do
    param 'Sensitive[String]', :sensitive
    param 'Type[Regexp]', :pattern
  end

  def split_String(str, pattern)
    str.split(Regexp.compile(pattern))
  end

  def split_Regexp(str, pattern)
    str.split(pattern)
  end

  def split_RegexpType(str, pattern)
    str.split(pattern.regexp)
  end

  def split_String_sensitive(sensitive, pattern)
    Puppet::Pops::Types::PSensitiveType::Sensitive.new(split_String(sensitive.unwrap, pattern))
  end

  def split_Regexp_sensitive(sensitive, pattern)
    Puppet::Pops::Types::PSensitiveType::Sensitive.new(split_Regexp(sensitive.unwrap, pattern))
  end

  def split_RegexpType_sensitive(sensitive, pattern)
    Puppet::Pops::Types::PSensitiveType::Sensitive.new(split_RegexpType(sensitive.unwrap, pattern))
  end
end
