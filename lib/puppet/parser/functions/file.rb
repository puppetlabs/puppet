require 'puppet/file_system'

Puppet::Parser::Functions::newfunction(
  :file, :arity => -2, :type => :rvalue,
  :doc => "Loads a file from a module and returns its contents as a string.

  The argument to this function should be a `<MODULE NAME>/<FILE>`
  reference, which will load `<FILE>` from a module's `files`
  directory. (For example, the reference `mysql/mysqltuner.pl` will load the
  file `<MODULES DIRECTORY>/mysql/files/mysqltuner.pl`.)

  This function can also accept:

  * An absolute path, which can load a file from anywhere on disk.
  * Multiple arguments, which will return the contents of the **first** file
  found, skipping any files that don't exist.
  "
) do |vals|
    path = nil
    vals.each do |file|
      found = Puppet::Parser::Files.find_file(file, compiler.environment)
      if found && Puppet::FileSystem.exist?(found)
        path = found
        break
      end
    end

    if path
      Puppet::FileSystem.read_preserve_line_endings(path)
    else
      raise Puppet::ParseError, _("Could not find any files from %{values}") % { values: vals.join(", ") }
    end
end
