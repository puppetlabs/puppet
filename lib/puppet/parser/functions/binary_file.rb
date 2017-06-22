Puppet::Parser::Functions::newfunction(
  :binary_file,
  :type => :rvalue,
  :arity => 1,
:doc => <<-DOC
Loads a binary file from a module or file system and returns its contents as a Binary.

The argument to this function should be a `<MODULE NAME>/<FILE>`
reference, which will load `<FILE>` from a module's `files`
directory. (For example, the reference `mysql/mysqltuner.pl` will load the
file `<MODULES DIRECTORY>/mysql/files/mysqltuner.pl`.)

This function also accepts an absolute file path that allows reading
binary file content from anywhere on disk.

An error is raised if the given file does not exists.

To search for the existence of files, use the `find_file()` function.

- since 4.8.0
DOC
) do |args|
  Puppet::Parser::Functions::Error.is4x('binary_file')
end
