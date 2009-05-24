# A support module for testing files.
module PuppetSpec::Files
    def tmpfile(name)
        source = Tempfile.new(name)
        path = source.path
        source.close!
        path
    end
end
