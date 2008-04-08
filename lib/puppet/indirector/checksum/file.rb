require 'puppet/checksum'
require 'puppet/indirector/file'

class Puppet::Checksum::File < Puppet::Indirector::File
    desc "Store files in a directory set based on their checksums."

    def initialize
        Puppet.settings.use(:filebucket)
    end

    def path(checksum)
        path = []
        path << Puppet[:bucketdir]                              # Start with the base directory
        path << checksum[0..7].split("").join(File::SEPARATOR)  # Add sets of directories based on the checksum
        path << checksum                                        # And the full checksum name itself
        path << "contents"                                      # And the actual file name

        path.join(File::SEPARATOR)
    end

    def save(request)
        path = File.dirname(path(request.key))

        # Make the directories if necessary.
        unless FileTest.directory?(path)
            Puppet::Util.withumask(0007) do
                FileUtils.mkdir_p(path)
            end
        end

        super
    end
end
