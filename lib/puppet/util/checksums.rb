# A stand-alone module for calculating checksums
# in a generic way.
module Puppet::Util::Checksums
  class FakeChecksum
    def <<(*args)
      self
    end
  end

  # Is the provided string a checksum?
  def checksum?(string)
    string =~ /^\{(\w{3,5})\}\S+/
  end

  # Strip the checksum type from an existing checksum
  def sumdata(checksum)
    checksum =~ /^\{(\w+)\}(.+)/ ? $2 : nil
  end

  # Strip the checksum type from an existing checksum
  def sumtype(checksum)
    checksum =~ /^\{(\w+)\}/ ? $1 : nil
  end

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

    digest = Digest::MD5.new
    checksum_file(digest, filename,  lite)
  end

  # Calculate a checksum of the first 500 chars of a file's content using Digest::MD5.
  def md5lite_file(filename)
    md5_file(filename, true)
  end

  def md5_stream(&block)
    require 'digest/md5'
    digest = Digest::MD5.new
    yield digest
    digest.hexdigest
  end

  alias :md5lite_stream :md5_stream

  # Return the :mtime timestamp of a file.
  def mtime_file(filename)
    File.stat(filename).send(:mtime)
  end

  # by definition this doesn't exist
  # but we still need to execute the block given
  def mtime_stream
    noop_digest = FakeChecksum.new
    yield noop_digest
    nil
  end

  def mtime(content)
    ""
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

    digest = Digest::SHA1.new
    checksum_file(digest, filename, lite)
  end

  # Calculate a checksum of the first 500 chars of a file's content using Digest::SHA1.
  def sha1lite_file(filename)
    sha1_file(filename, true)
  end

  def sha1_stream
    require 'digest/sha1'
    digest = Digest::SHA1.new
    yield digest
    digest.hexdigest
  end

  alias :sha1lite_stream :sha1_stream

  # Return the :ctime of a file.
  def ctime_file(filename)
    File.stat(filename).send(:ctime)
  end

  alias :ctime_stream :mtime_stream

  def ctime(content)
    ""
  end

  # Return a "no checksum"
  def none_file(filename)
    ""
  end

  def none_stream
    noop_digest = FakeChecksum.new
    yield noop_digest
    ""
  end

  def none(content)
    ""
  end

  private

  # Perform an incremental checksum on a file.
  def checksum_file(digest, filename, lite = false)
    buffer = lite ? 512 : 4096
    File.open(filename, 'rb') do |file|
      while content = file.read(buffer)
        digest << content
        break if lite
      end
    end

    digest.hexdigest
  end
end
