module Puppet::Util::Checksums
    def md5(content)
        require 'digest/md5'
        Digest::MD5.hexdigest(content)
    end

    def md5_file(filename)
        require 'digest/md5'

        incr_digest = Digest::MD5.new()
        File.open(filename, 'r') do |file|
            file.each_line do |line|
                incr_digest << line
            end
        end

        return incr_digest.hexdigest
    end

    def sha1(content)
        require 'digest/sha1'
        Digest::SHA1.hexdigest(content)
    end

    def sha1_file(filename)
        require 'digest/sha1'

        incr_digest = Digest::SHA1.new()
        File.open(filename, 'r') do |file|
            file.each_line do |line|
                incr_digest << line
            end
        end

        return incr_digest.hexdigest
    end
end
