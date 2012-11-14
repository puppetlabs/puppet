
module Puppet; module Pops; module API;
  # The Patterns module contains common regular expression patters for the Puppet DSL language
  module Patterns
  # Numeric matches hex, octal, decimal, and floating point and captures three parts
  # 0 = entire matched number, leading and trailing whitespace included
  # 1 = hexadecimal number
  # 2 = non hex integer portion, possibly with leading 0 (octal)
  # 3 = floating point part, starts with ".", decimals and optional exponent
  #
  # Thus, a hex number has group 1 value, an octal value has group 2 (if it starts with 0), and no group 3
  # and a floating point value has group 2 and group 3.
  #
  NUMERIC = %r{^\s*(?:(0[xX][0-9A-Fa-f]+)|(0?\d+)((?:\.\d+)?(?:[eE]-?\d+)?))\s*$}
  end
end; end; end;