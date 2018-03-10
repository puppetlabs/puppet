# Finds an existing module and returns the path to its root directory.
#
# The argument to this function should be a module name String
# For example, the reference `mysql` will search for the
# directory `<MODULES DIRECTORY>/mysql` and return the first
# found on the modulepath.
#
# This function can also accept:
#
# * Multiple String arguments, which will return the path of the **first** module
#  found, skipping non existing modules.
# * An array of module names, which will return the path of the **first** module
#  found from the given names in the array, skipping non existing modules.
#
# The function returns `undef` if none of the given modules were found
#
# @since 5.4.0
#
Puppet::Functions.create_function(:module_directory, Puppet::Functions::InternalFunction) do
  dispatch :module_directory do
    scope_param
    repeated_param 'String', :names
  end

  dispatch :module_directory_array do
    scope_param
    repeated_param 'Array[String]', :names
  end

  def module_directory_array(scope, names)
    module_directory(scope, *names)
  end

  def module_directory(scope, *names)
    names.each do |module_name|
      found = scope.compiler.environment.module(module_name)
      return found.path if found
    end
    nil
  end
end
