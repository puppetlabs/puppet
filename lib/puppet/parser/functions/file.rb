# Returns the contents of a file

Puppet::Parser::Functions::newfunction(
  :file, :arity => -2, :type => :rvalue,
  :doc => "Return the contents of a file.  Multiple files
  can be passed, and the first file that exists will be read in."
) do |vals|
    ret = nil
    vals.each do |file|
      path = Puppet::Parser::Files.find_file(file, compiler.environment)
      if not path.nil? and Puppet::FileSystem.exist?(path)
        ret = File.read(path)
        break
      end
    end
    if ret
      ret
    else
      raise Puppet::ParseError, "Could not find any files from #{vals.join(", ")}"
    end
end
