# The Patterns module contains common regular expression patters for the Puppet DSL language
module Puppet::Pops::Patterns

  # NUMERIC matches hex, octal, decimal, and floating point and captures three parts
  # 0 = entire matched number, leading and trailing whitespace included
  # 1 = hexadecimal number
  # 2 = non hex integer portion, possibly with leading 0 (octal)
  # 3 = floating point part, starts with ".", decimals and optional exponent
  #
  # Thus, a hex number has group 1 value, an octal value has group 2 (if it starts with 0), and no group 3
  # and a floating point value has group 2 and group 3.
  #
  NUMERIC = %r{^\s*(?:(0[xX][0-9A-Fa-f]+)|(0?\d+)((?:\.\d+)?(?:[eE]-?\d+)?))\s*$}

  # ILLEGAL_P3_1_HOSTNAME matches if a hostname contains illegal characters.
  # This check does not prevent pathological names like 'a....b', '.....', "---". etc.
  ILLEGAL_HOSTNAME_CHARS = %r{[^-\w.]}

  # NAME matches a name the same way as the lexer.
  # This name includes hyphen, which may be illegal in variables, and names in general.
  NAME = %r{((::)?[a-z0-9][-\w]*)(::[a-z0-9][-\w]*)*}

  # CLASSREF_EXT matches a class reference the same way as the lexer - i.e. the external source form
  # where each part must start with a capital letter A-Z.
  # This name includes hyphen, which may be illegal in some cases.
  #
  CLASSREF_EXT = %r{((::){0,1}[A-Z][-\w]*)+}

  # CLASSREF matches a class reference the way it is represented internall in the
  # model (i.e. in lower case).
  # This name includes hyphen, which may be illegal in some cases.
  #
  CLASSREF = %r{((::){0,1}[a-z][-\w]*)+}

end
