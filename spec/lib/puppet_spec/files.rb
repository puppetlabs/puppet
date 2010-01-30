require 'fileutils'

# A support module for testing files.
module PuppetSpec::Files
    def tmpfile(name)
        source = Tempfile.new(name)
        path = source.path
        source.close!
        $tmpfiles ||= []
        $tmpfiles << path
        path
    end

    def tmpdir(name)
        file = tmpfile(name)
        FileUtils.mkdir_p(file)
        file
    end
end
