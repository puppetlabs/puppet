Puppet::Parser::Functions::newfunction(
  :file, :arity => -2, :type => :rvalue,
  :doc => "Return the contents of a single file from a list of file selectors.
  The file selectors are used in turn to find a file. The first file that is
  found is read and the contents are returned. If no files are found an error
  is raised.

  A file selector can either be an absolute path or be a module reference in
  the form `modulename/filename`. A module reference will find the `filename`
  relative the files directory of a module with the given `modulename`.
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
      File.read(path)
    else
      raise Puppet::ParseError, "Could not find any files from #{vals.join(", ")}"
    end
end
