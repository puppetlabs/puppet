# Windows

If you'd like to run Puppet from source on Windows platforms, follow the [Quickstart](./quickstart.md) to using bundler and installing the necessary gems on Windows.

You will need to install Ruby on Windows from [rubyinstaller.org](http://rubyinstaller.org).

    C:\> cd C:\work\puppet
    C:\work\puppet> gem install bundler
    C:\work\puppet> bundle install --path .bundle
    C:\work\puppet> bundle exec puppet --version
    4.7.1

When writing a test that cannot possibly run on Windows, e.g. there is
no mount type on windows, do the following:

    describe Puppet::MyClass, :unless => Puppet.features.microsoft_windows? do
      ..
    end

If the test doesn't currently pass on Windows, e.g. due to on going porting, then use an rspec conditional pending block:

    pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
      <example1>
    end

    pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
      <example2>
    end

Then run the test as:

    C:\work\puppet> bundle exec rspec spec

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
   child's HANDLE and retrieve its exit code.  Use Puppet::Util::Execution.execute.

 * Don't assume 'C' drive.  Use environment variables to look these up:

    "#{ENV['windir']}/system32/netsh.exe"

