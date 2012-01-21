# Developer README #

This file is intended to provide a place for developers and contributors to
document what other developers need to know about changes made to Puppet.

# UTF-8 Handling #

As Ruby 1.9 becomes more commonly used with Puppet, developers should be aware
of major changes to the way Strings and Regexp objects are handled.
Specifically, every instance of these two classes will have an encoding
attribute determined in a number of ways.

 * If the source file has an encoding specified in the magic comment at the
   top, the instance will take on that encoding.
 * Otherwise, the encoding will be determined by the LC\_LANG or LANG
   environment variables.
 * Otherwise, the encoding will default to ASCII-8BIT

## References ##

Excellent information about the differences between encodings in Ruby 1.8 and
Ruby 1.9 is published in this blog series:
[Understanding M17n](http://links.puppetlabs.com/understanding_m17n)

## Encodings of Regexp and String instances ##

In general, please be aware that Ruby 1.9 regular expressions need to be
compatible with the encoding of a string being used to match them.  If they are
not compatible you can expect to receive and error such as:

    Encoding::CompatibilityError: incompatible encoding regexp match (ASCII-8BIT
    regexp with UTF-8 string)

In addition, some escape sequences were valid in Ruby 1.8 are no longer valid
in 1.9 if the regular expression is not marked as an ASCII-8BIT object.  You
may expect errors like this in this situation:

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

Puppet provides a monkey patch to String which returns an encoding suitable for
byte manipulations:

    # Example of how to escape non ASCII printable characters for YAML.
    >> snowman = "☃"
    >> snowman.to_ascii8bit.gsub(/([\x80-\xFF])/n) { |x| "\\x#{x.unpack("C")[0].to_s(16)} }
    => "\\xe2\\x98\\x83"

If the Regexp is not marked as ASCII-8BIT using /n, then you can expect the
SyntaxError, invalid multibyte escape as mentioned above.

# Windows #

If you'd like to run Puppet from source on Windows platforms, the
include `ext/envpuppet.bat` will help.  All file paths in the Puppet
code base should use a path separator of / regardless of Windows or
Unix filesystem.

To quickly run Puppet from source, assuming you already have Ruby installed
from [rubyinstaller.org](http://rubyinstaller.org).

    gem install sys-admin win32-process win32-dir win32-taskscheduler --no-rdoc --no-ri
    gem install win32-service --platform=mswin32 --no-rdoc --no-ri --version 0.7.1
    net use Z: "\\vmware-host\Shared Folders" /persistent:yes
    Z:
    cd <path_to_puppet>
    set PATH=%PATH%;Z:\<path_to_puppet>\ext
    envpuppet puppet --version
    2.7.9

Some spec tests are known to fail on Windows, e.g. no mount provider
on Windows, so use the following rspec exclude filter:

    cd <path_to_puppet>
    envpuppet rspec --tag ~fails_on_windows spec

This will give you a shared filesystem with your Mac and allow you to run
Puppet directly from source without using install.rb or copying files around.

EOF
