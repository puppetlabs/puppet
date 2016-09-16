# Finds an existing file from a module and returns its path.
# (Documented in 3.x stub)
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
    path = nil
    args.each do |file|
      found = Puppet::Parser::Files.find_file(file, scope.compiler.environment)
      if found && Puppet::FileSystem.exist?(found)
        return found
      end
    end
    nil
  end
end
