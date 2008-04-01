# A stand-alone module for calculating checksums
# in a generic way.
module Puppet::Util::Checksums
    # Calculate a checksum using Digest::MD5.
    def md5(content)
        require 'digest/md5'
        Digest::MD5.hexdigest(content)
    end

    # Calculate a checksum of the first 500 chars of the content using Digest::MD5.
    def md5lite(content)
        md5(content[0..511])
    end

    # Calculate a checksum of a file's content using Digest::MD5.
    def md5_file(filename, lite = false)
        require 'digest/md5'

        digest = Digest::MD5.new()
        return checksum_file(digest, filename,  lite)
    end

    # Calculate a checksum of the first 500 chars of a file's content using Digest::MD5.
    def md5lite_file(filename)
        md5_file(filename, true)
    end

    # Return the :mtime timestamp of a file.
    def mtime_file(filename)
        File.stat(filename).send(:mtime)
    end

    # Calculate a checksum using Digest::SHA1.
    def sha1(content)
        require 'digest/sha1'
        Digest::SHA1.hexdigest(content)
    end

    # Calculate a checksum of the first 500 chars of the content using Digest::SHA1.
    def sha1lite(content)
        sha1(content[0..511])
    end

    # Calculate a checksum of a file's content using Digest::SHA1.
    def sha1_file(filename, lite = false)
        require 'digest/sha1'

        digest = Digest::SHA1.new()
        return checksum_file(digest, filename, lite)
    end

    # Calculate a checksum of the first 500 chars of a file's content using Digest::SHA1.
    def sha1lite_file(filename)
        sha1_file(filename, true)
    end

    # Return the :ctime of a file.
    def ctime_file(filename)
        File.stat(filename).send(:ctime)
    end

    private

    # Perform an incremental checksum on a file.
    def checksum_file(digest, filename, lite = false)
        File.open(filename, 'r') do |file|
            while content = file.read(512)
                digest << content
                break if lite
            end
        end

        return digest.hexdigest
    end
end
