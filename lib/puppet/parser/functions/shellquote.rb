module Puppet::Parser::Functions

    Safe = 'a-zA-Z0-9@%_+=:,./-'    # Safe unquoted
    Dangerous = '!"`$\\'            # Unsafe inside double quotes

    newfunction(:shellquote, :type => :rvalue, :doc => "\
        Quote and concatenate arguments for use in Bourne shell.

        Each argument is quoted separately, and then all are concatenated
        with spaces.  If an argument is an array, the elements of that
        array is interpolated within the rest of the arguments; this makes
        it possible to have an array of arguments and pass that array to
        shellquote() instead of having to specify each argument
        individually in the call.
        ") \
    do |args|

        result = []
        args.flatten.each do |word|
            if word.length != 0 and word.count(Safe) == word.length
                result << word
            elsif word.count(Dangerous) == 0
                result << ('"' + word + '"')
            elsif word.count("'") == 0
                result << ("'" + word + "'")
            else
                r = '"'
                word.each_byte() do |c|
                    if Dangerous.include?(c)
                        r += "\\"
                    end
                    r += c.chr()
                end
                r += '"'
                result << r
            end
        end

        return result.join(" ")
    end
end
