# Loads a binary file from a module or file system and returns its contents as a Binary.
#
# The argument to this function should be a `<MODULE NAME>/<FILE>`
# reference, which will load `<FILE>` from a module's `files`
# directory. (For example, the reference `mysql/mysqltuner.pl` will load the
# file `<MODULES DIRECTORY>/mysql/files/mysqltuner.pl`.)
#
# This function also accepts an absolute file path that allows reading
# binary file content from anywhere on disk.
#
# An error is raised if the given file does not exists.
#
# To search for the existence of files, use the `find_file()` function.
#
# @since 4.6.0
#
Puppet::Functions.create_function(:binary_file, Puppet::Functions::InternalFunction) do
  dispatch :binary_file do
    scope_param
    param 'String', :path
  end

  def binary_file(scope, unresolved_path)
    path = nil
    found = Puppet::Parser::Files.find_file(unresolved_path, scope.compiler.environment)
    if found && Puppet::FileSystem.exist?(found)
      path = found
    end

    if path
      Puppet::Pops::Types::PBinaryType::Binary.from_binary_string(Puppet::FileSystem.binread(path))
    else
      raise Puppet::ParseError, "binary_file(): The given file '#{path}' does not exist"
    end
  end
end
