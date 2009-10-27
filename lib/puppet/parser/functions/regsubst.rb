module Puppet::Parser::Functions
    newfunction(:regsubst, :type => :rvalue,
                :doc => "
                Perform regexp replacement on a string or array of strings.

- **Parameters** (in order):

:target:  The string or array of strings to operate on.  If an array, the replacement will be performed on each of the elements in the array, and the return value will be an array.

:regexp:  The regular expression matching the target string.  If you want it anchored at the start and or end of the string, you must do that with ^ and $ yourself.

:replacement:  Replacement string. Can contain back references to what was matched using \\0, \\1, and so on.

:flags:  Optional. String of single letter flags for how the regexp is interpreted:

    - **E**         Extended regexps
    - **I**         Ignore case in regexps
    - **M**         Multiline regexps
    - **G**         Global replacement; all occurrences of the regexp in each target string will be replaced.  Without this, only the first occurrence will be replaced.

:lang:  Optional.  How to handle multibyte characters.  A single-character string with the following values:

     - **N**         None
     - **E**         EUC
     - **S**         SJIS
     - **U**         UTF-8

- **Examples**

Get the third octet from the node's IP address::

    $i3 = regsubst($ipaddress,'^([0-9]+)[.]([0-9]+)[.]([0-9]+)[.]([0-9]+)$','\\3')

Put angle brackets around each octet in the node's IP address::

    $x = regsubst($ipaddress, '([0-9]+)', '<\\1>', 'G')
") \
    do |args|
        unless args.length.between?(3, 5)
            raise(Puppet::ParseError,
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
            raise(Puppet::ParseError,
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
            raise(Puppet::ParseError,
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
            raise(Puppet::ParseError,
                  "regsubst(): bad target #{target.class}:`#{target}'")
        end
        return result
    end
end
