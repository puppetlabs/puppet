# UTF-8 Handling #

Now that Puppet only supports Ruby 1.9+, developers should be aware
of how Ruby handles Strings and Regexp objects. Specifically, every 
instance of these two classes will have an encoding attribute determined
in a number of ways.

 * If the source file has an encoding specified in the magic comment at the
   top, the instance will take on that encoding.
 * Otherwise, the encoding will be determined by the LC\_LANG or LANG
   environment variables.
 * Otherwise, the encoding will default to ASCII-8BIT

## Encodings of Regexp and String instances ##

In general, please be aware that Ruby regular expressions need to be
compatible with the encoding of a string being used to match them.  If they are
not compatible you can expect to receive an error such as:

    Encoding::CompatibilityError: incompatible encoding regexp match (ASCII-8BIT
    regexp with UTF-8 string)

In addition, some escape sequences are only valid if the regular expression is
marked as an ASCII-8BIT object. If the regular expression is not marked as
ASCII-8BIT, you can get an error such as:

    SyntaxError: (irb):7: invalid multibyte escape: /\xFF/

This error is particularly common when serializing a string to other
representations like JSON or YAML.  To resolve the problem you can explicitly
mark the regular expression as ASCII-8BIT using the /n flag:

    "a" =~ /\342\230\203/n

Finally, any time you're thinking of a string as an array of bytes rather than
an array of characters, common when escaping a string, you should work with
everything in ASCII-8BIT.  Changing the encoding will not change the data
itself and allow the Regexp and the String to deal with bytes rather than
characters.
