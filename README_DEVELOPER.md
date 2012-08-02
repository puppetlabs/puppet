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
include `ext/envpuppet.bat` will help.

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

## Common Issues ##

 * Don't assume file paths start with '/', as that is not a valid path on
   Windows.  Use Puppet::Util.absolute\_path? to validate that a path is fully
   qualified.

 * Use File.expand\_path('/tmp') in tests to generate a fully qualified path
   that is valid on POSIX and Windows.  In the latter case, the current working
   directory will be used to expand the path.

 * Always use binary mode when performing file I/O, unless you explicitly want
   Ruby to translate between unix and dos line endings.  For example, opening an
   executable file in text mode will almost certainly corrupt the resulting
   stream, as will occur when using:

     IO.open(path, 'r') { |f| ... }
     IO.read(path)

   If in doubt, specify binary mode explicitly:

     IO.open(path, 'rb')

 * Don't assume file paths are separated by ':'.  Use `File::PATH_SEPARATOR`
   instead, which is ':' on POSIX and ';' on Windows.

 * On Windows, `File::SEPARATOR` is '/', and `File::ALT_SEPARATOR` is '\'.  On
   POSIX systems, `File::ALT_SEPARATOR` is nil.  In general, use '/' as the
   separator as most Windows APIs, e.g. CreateFile, accept both types of
   separators.

 * Don't use waitpid/waitpid2 if you need the child process' exit code,
   as the child process may exit before it has a chance to open the
   child's HANDLE and retrieve its exit code.  Use Puppet::Util.execute.

 * Don't assume 'C' drive.  Use environment variables to look these up:

    "#{ENV['windir']}/system32/netsh.exe"

# Configuration Directory #

In Puppet 3.x we've simplified the behavior of selecting a configuration file
to load.  The intended behavior of reading `puppet.conf` is:

 1. Use the explicit configuration provided by --confdir or --config if present
 2. If running as root (`Puppet.features.root?`) then use the system
    `puppet.conf`
 3. Otherwise, use `~/.puppet/puppet.conf`.

When Puppet master is started from Rack, Puppet 3.x will read from
~/.puppet/puppet.conf by default.  This is intended behavior.  Rack
configurations should start Puppet master with an explicit configuration
directory using `ARGV << "--confdir" << "/etc/puppet"`.  Please see the
`ext/rack/files/config.ru` file for an up-to-date example.

EOF
