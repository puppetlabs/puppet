# Loads a binary file from a module or file system and returns its contents as a Binary.
# (Documented in 3.x stub)
#
# @since 4.8.0
#
Puppet::Functions.create_function(:binary_file, Puppet::Functions::InternalFunction) do
  dispatch :binary_file do
    scope_param
    param 'String', :path
  end

  def binary_file(scope, unresolved_path)
    path = Puppet::Parser::Files.find_file(unresolved_path, scope.compiler.environment)
    unless path && Puppet::FileSystem.exist?(path)
      raise Puppet::ParseError, "binary_file(): The given file '#{unresolved_path}' does not exist"
    end
    Puppet::Pops::Types::PBinaryType::Binary.from_binary_string(Puppet::FileSystem.binread(path))
  end
end
