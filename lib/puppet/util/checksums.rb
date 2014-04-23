require 'digest/md5'
require 'digest/sha1'

# A stand-alone module for calculating checksums
# in a generic way.
module Puppet::Util::Checksums
  # @deprecated
  # In Puppet 4 we should switch this to `module_function` to make these methods
  # private when this class is included.
  extend self

  # It's not a good idea to use some of these in some contexts: for example, I
  # wouldn't try bucketing a file using the :none checksum type.
  def known_checksum_types
    [:sha256, :sha256lite, :md5, :md5lite, :sha1, :sha1lite,
      :mtime, :ctime, :none]
  end

  class FakeChecksum
    def <<(*args)
      self
    end
  end

  # Is the provided string a checksum?
  def checksum?(string)
    # 'sha256lite'.length == 10
    string =~ /^\{(\w{3,10})\}\S+/
  end

  # Strip the checksum type from an existing checksum
  def sumdata(checksum)
    checksum =~ /^\{(\w+)\}(.+)/ ? $2 : nil
  end

  # Strip the checksum type from an existing checksum
  def sumtype(checksum)
    checksum =~ /^\{(\w+)\}/ ? $1 : nil
  end

  # Calculate a checksum using Digest::SHA256.
  def sha256(content)
    require 'digest/sha2'
    Digest::SHA256.hexdigest(content)
  end

  def sha256lite(content)
    sha256(content[0..511])
  end

  def sha256_file(filename, lite = false)
    require 'digest/sha2'

    digest = Digest::SHA256.new
    checksum_file(digest, filename,  lite)
  end

  def sha256lite_file(filename)
    sha256_file(filename, true)
  end

  def sha256_stream(&block)
    require 'digest/sha2'
    digest = Digest::SHA256.new
    yield digest
    digest.hexdigest
  end

  def sha256_hex_length
    64
  end

  alias :sha256lite_stream :sha256_stream
  alias :sha256lite_hex_length :sha256_hex_length

  # Calculate a checksum using Digest::MD5.
  def md5(content)
    Digest::MD5.hexdigest(content)
  end

  # Calculate a checksum of the first 500 chars of the content using Digest::MD5.
  def md5lite(content)
    md5(content[0..511])
  end

  # Calculate a checksum of a file's content using Digest::MD5.
  def md5_file(filename, lite = false)
    digest = Digest::MD5.new
    checksum_file(digest, filename,  lite)
  end

  # Calculate a checksum of the first 500 chars of a file's content using Digest::MD5.
  def md5lite_file(filename)
    md5_file(filename, true)
  end

  def md5_stream(&block)
    digest = Digest::MD5.new
    yield digest
    digest.hexdigest
  end

  def md5_hex_length
    32
  end

  alias :md5lite_stream :md5_stream
  alias :md5lite_hex_length :md5_hex_length

  # Return the :mtime timestamp of a file.
  def mtime_file(filename)
    Puppet::FileSystem.stat(filename).send(:mtime)
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
    Digest::SHA1.hexdigest(content)
  end

  # Calculate a checksum of the first 500 chars of the content using Digest::SHA1.
  def sha1lite(content)
    sha1(content[0..511])
  end

  # Calculate a checksum of a file's content using Digest::SHA1.
  def sha1_file(filename, lite = false)
    digest = Digest::SHA1.new
    checksum_file(digest, filename, lite)
  end

  # Calculate a checksum of the first 500 chars of a file's content using Digest::SHA1.
  def sha1lite_file(filename)
    sha1_file(filename, true)
  end

  def sha1_stream
    digest = Digest::SHA1.new
    yield digest
    digest.hexdigest
  end

  def sha1_hex_length
    40
  end

  alias :sha1lite_stream :sha1_stream
  alias :sha1lite_hex_length :sha1_hex_length

  # Return the :ctime of a file.
  def ctime_file(filename)
    Puppet::FileSystem.stat(filename).send(:ctime)
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
