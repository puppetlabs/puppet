Puppet::Parser::Functions::newfunction(
  :find_file,
  :type => :rvalue,
  :arity => -2,
:doc => <<-DOC
Finds an existing file from a module and returns its path.

The argument to this function should be a String as a `<MODULE NAME>/<FILE>`
reference, which will search for `<FILE>` relative to a module's `files`
directory. (For example, the reference `mysql/mysqltuner.pl` will search for the
file `<MODULES DIRECTORY>/mysql/files/mysqltuner.pl`.)

This function can also accept:

* An absolute String path, which will check for the existence of a file from anywhere on disk.
* Multiple String arguments, which will return the path of the **first** file
  found, skipping non existing files.
* An array of string paths, which will return the path of the **first** file
  found from the given paths in the array, skipping non existing files.

The function returns `undef` if none of the given paths were found

- since 4.8.0
DOC
) do |args|
  Puppet::Parser::Functions::Error.is4x('find_file')
end

