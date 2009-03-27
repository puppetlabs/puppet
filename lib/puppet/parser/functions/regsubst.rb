module Puppet::Parser::Functions
    newfunction(:regsubst, :type => :rvalue,
		:doc => "Perform regexp replacement on a string.

	Parameters (in order):

	:str:
		The string to operate on.

	:regexp:
		The regular expression matching the string.  If you want it
		anchored at the start and/or end of the string, you must do
		that with ^ and $ yourself.

	:replacement:
		Replacement string.  Can contain back references to what was
		matched using \\0, \\1, and so on.

	:flags:
		Optional.  String of single letter flags for how the regexp
		is interpreted:

		- **E**
			Extended regexps
		- **I**
			Ignore case in regexps
		- **M**
			Multiline regexps
		- **G**
			Global replacement; all occurances of the regexp in
			the string will be replaced.  Without this, only the
			first occurance will be replaced.

	:lang:
		Optional.  How to handle multibyte characters.  A
		single-character string with the following values:

		- **N**
			None
		- **E**
			EUC
		- **S**
			SJIS
		- **U**
			UTF-8

	**Examples**

	Get the third octet from the node's IP address: ::

	    $i3 = regsubst($ipaddress,
			   '^([0-9]+)[.]([0-9]+)[.]([0-9]+)[.]([0-9]+)$',
			   '\\\\3')

	Put angle brackets around each octet in the node's IP address: ::

	    $x = regsubst($ipaddress, '([0-9]+)', '<\\\\1>', 'G')") \
        do |args|
	flag_mapping = {
	    "E" => Regexp::EXTENDED,
	    "I" => Regexp::IGNORECASE,
	    "M" => Regexp::MULTILINE,
	}
	if args.length < 3  or  args.length > 5
	    raise Puppet::ParseError, ("regsub(): wrong number of arguments" +
				       " (#{args.length}; min 3, max 5)")
	end
	str, regexp, replacement, flags, lang = args
	reflags = 0
	global = false
	(flags or "").each_byte do |f|
	    f = f.chr
	    if f == "G"
		global = true
	    else
		fvalue = flag_mapping[f]
		if !fvalue
		    raise Puppet::ParseError, "regsub(): bad flag `#{f}'"
		end
		reflags |= fvalue
	    end
	end
	re = Regexp.compile(regexp, reflags, lang)
	if global
	    result = str.gsub(re, replacement)
	else
	    result = str.sub(re, replacement)
	end
	return result
    end
end
