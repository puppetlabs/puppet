# Returns the contents of a file
Puppet::Parser::Functions::newfunction(:file, :type => :rvalue,
        :doc => "Return the contents of a file.  Multiple files
        can be passed, and the first file that exists will be read in.") do |vals|
            ret = nil
            vals.each do |file|
                unless file =~ /^#{File::SEPARATOR}/
                    raise Puppet::ParseError, "Files must be fully qualified"
                end
                if FileTest.exists?(file)
                    ret = File.read(file)
                    break
                end
            end
            if ret
                ret
            else
                raise Puppet::ParseError, "Could not find any files from %s" %
                    vals.join(", ")
            end
end
