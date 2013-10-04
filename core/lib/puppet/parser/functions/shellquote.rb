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

Puppet::Parser::Functions.newfunction(:shellquote, :type => :rvalue, :arity => -1, :doc => "\
    Quote and concatenate arguments for use in Bourne shell.

    Each argument is quoted separately, and then all are concatenated
    with spaces.  If an argument is an array, the elements of that
    array is interpolated within the rest of the arguments; this makes
    it possible to have an array of arguments and pass that array to
    shellquote instead of having to specify each argument
    individually in the call.
    ") \
do |args|
  safe = 'a-zA-Z0-9@%_+=:,./-'    # Safe unquoted
  dangerous = '!"`$\\'            # Unsafe inside double quotes

  result = []
  args.flatten.each do |word|
    if word.length != 0 and word.count(safe) == word.length
      result << word
    elsif word.count(dangerous) == 0
      result << ('"' + word + '"')
    elsif word.count("'") == 0
      result << ("'" + word + "'")
    else
      r = '"'
      word.each_byte do |c|
        r += "\\" if dangerous.include?(c.chr)
        r += c.chr
      end
      r += '"'
      result << r
    end
  end

  return result.join(" ")
end
