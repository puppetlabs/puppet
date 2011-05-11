# Copyright (C) 2009 Thomas Bellman
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THOMAS BELLMAN BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# Except as contained in this notice, the name of Thomas Bellman shall
# not be used in advertising or otherwise to promote the sale, use or
# other dealings in this Software without prior written authorization
# from Thomas Bellman.

module Puppet::Parser::Functions

  newfunction(
  :regsubst, :type => :rvalue,

  :doc => "
Perform regexp replacement on a string or array of strings.

* *Parameters* (in order):
    * _target_  The string or array of strings to operate on.  If an array, the replacement will be performed on each of the elements in the array, and the return value will be an array.
    * _regexp_  The regular expression matching the target string.  If you want it anchored at the start and or end of the string, you must do that with ^ and $ yourself.
    * _replacement_  Replacement string. Can contain backreferences to what was matched using \\0 (whole match), \\1 (first set of parentheses), and so on.
    * _flags_  Optional. String of single letter flags for how the regexp is interpreted:
        - *E*         Extended regexps
        - *I*         Ignore case in regexps
        - *M*         Multiline regexps
        - *G*         Global replacement; all occurrences of the regexp in each target string will be replaced.  Without this, only the first occurrence will be replaced.
    * _encoding_  Optional.  How to handle multibyte characters.  A single-character string with the following values:
        - *N*         None
        - *E*         EUC
        - *S*         SJIS
        - *U*         UTF-8

* *Examples*

Get the third octet from the node's IP address:

    $i3 = regsubst($ipaddress,'^(\\d+)\\.(\\d+)\\.(\\d+)\\.(\\d+)$','\\3')

Put angle brackets around each octet in the node's IP address:

    $x = regsubst($ipaddress, '([0-9]+)', '<\\1>', 'G')
") \
  do |args|
    unless args.length.between?(3, 5)

      raise(
        Puppet::ParseError,

          "regsubst(): got #{args.length} arguments, expected 3 to 5")
    end
    target, regexp, replacement, flags, lang = args
    reflags = 0
    operation = :sub
    if flags == nil
      flags = []
    elsif flags.respond_to?(:split)
      flags = flags.split('')
    else

      raise(
        Puppet::ParseError,

          "regsubst(): bad flags parameter #{flags.class}:`#{flags}'")
    end
    flags.each do |f|
      case f
      when 'G' then operation = :gsub
      when 'E' then reflags |= Regexp::EXTENDED
      when 'I' then reflags |= Regexp::IGNORECASE
      when 'M' then reflags |= Regexp::MULTILINE
      else raise(Puppet::ParseError, "regsubst(): bad flag `#{f}'")
      end
    end
    begin
      re = Regexp.compile(regexp, reflags, lang)
    rescue RegexpError, TypeError

      raise(
        Puppet::ParseError,

          "regsubst(): Bad regular expression `#{regexp}'")
    end
    if target.respond_to?(operation)
      # String parameter -> string result
      result = target.send(operation, re, replacement)
    elsif target.respond_to?(:collect) and
      target.respond_to?(:all?) and
      target.all? { |e| e.respond_to?(operation) }
      # Array parameter -> array result
      result = target.collect { |e|
        e.send(operation, re, replacement)
      }
    else

      raise(
        Puppet::ParseError,

          "regsubst(): bad target #{target.class}:`#{target}'")
    end
    return result
  end
end
