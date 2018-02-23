# Finds an existing file from a module and returns its path.
#
# `find_file(<MODULE NAME>/<FILE>)`
#
# The argument to this function should be a String as a `<MODULE NAME>/<FILE>`
# reference, which will search for the given `<FILE>` relative to a module's `files`
# directory.
#
# @example Finding a file in a module
#
# To find the file `<MODULES DIRECTORY>/mysql/files/mysqltuner.pl`, use:
#
# ``` puppet
# find_file(`mysql/mysqltuner.pl`)
# ```
#
# This function can also accept:
#
# -   An absolute String path, which checks for the existence of a file from anywhere on
#     disk.
# -   Multiple String arguments, which will return the path of the **first** file
#     found, skipping non existing files.
# -   An array of string paths, which will return the path of the **first** file
#     found from the given paths in the array, skipping non existing files.
#
# The function returns `undef` if it cannot find any of the given paths.
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
