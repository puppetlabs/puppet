# frozen_string_literal: true

# Finds an existing file from a module and returns its path.
#
# This function accepts an argument that is a String as a `<MODULE NAME>/<FILE>`
# reference, which searches for `<FILE>` relative to a module's `files`
# directory. (For example, the reference `mysql/mysqltuner.pl` will search for the
# file `<MODULES DIRECTORY>/mysql/files/mysqltuner.pl`.)
#
# If this function is run via puppet agent, it checks for file existence on the
# Puppet Primary server. If run via puppet apply, it checks on the local host.
# In both cases, the check is performed before any resources are changed.
#
# This function can also accept:
#
# * An absolute String path, which checks for the existence of a file from anywhere on disk.
# * Multiple String arguments, which returns the path of the **first** file
#   found, skipping nonexistent files.
# * An array of string paths, which returns the path of the **first** file
#   found from the given paths in the array, skipping nonexistent files.
#
# The function returns `undef` if none of the given paths were found.
#
# @since 4.8.0
#
Puppet::Functions.create_function(:find_file, Puppet::Functions::InternalFunction) do
  dispatch :find_file do
    scope_param
    repeated_param 'String', :paths
  end

  dispatch :find_file_array do
    scope_param
    repeated_param 'Array[String]', :paths_array
  end

  def find_file_array(scope, array)
    find_file(scope, *array)
  end

  def find_file(scope, *args)
    args.each do |file|
      found = Puppet::Parser::Files.find_file(file, scope.compiler.environment)
      if found && Puppet::FileSystem.exist?(found)
        return found
      end
    end
    nil
  end
end
