require 'digest/md5'
require 'digest/sha1'
require 'time'

# A stand-alone module for calculating checksums
# in a generic way.
module Puppet::Util::Checksums
  module_function

  # It's not a good idea to use some of these in some contexts: for example, I
  # wouldn't try bucketing a file using the :none checksum type.
  def known_checksum_types
    [:sha256, :sha256lite, :md5, :md5lite, :sha1, :sha1lite, :sha512, :sha384, :sha224, 
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

  def sha256?(string)
    string =~ /^\h{64}$/
  end

  def sha256_file(filename, lite = false)
    require 'digest/sha2'

    digest = Digest::SHA256.new
    checksum_file(digest, filename,  lite)
  end

  def sha256_stream(lite = false, &block)
    require 'digest/sha2'
    digest = Digest::SHA256.new
    checksum_stream(digest, block, lite)
  end

  def sha256_hex_length
    64
  end

  def sha256lite(content)
    sha256(content[0..511])
  end

  def sha256lite?(string)
    sha256?(string)
  end

  def sha256lite_file(filename)
    sha256_file(filename, true)
  end

  def sha256lite_stream(&block)
    sha256_stream(true, &block)
  end

  def sha256lite_hex_length
    sha256_hex_length
  end

  # Calculate a checksum using Digest::SHA384.
  def sha384(content)
    require 'digest/sha2'
    Digest::SHA384.hexdigest(content)
  end

  def sha384?(string)
    string =~ /^\h{96}$/
  end

  def sha384_file(filename, lite = false)
    require 'digest/sha2'

    digest = Digest::SHA384.new
    checksum_file(digest, filename,  lite)
  end

  def sha384_stream(lite = false, &block)
    require 'digest/sha2'
    digest = Digest::SHA384.new
    checksum_stream(digest, block, lite)
  end

  def sha384_hex_length
    96
  end

  # Calculate a checksum using Digest::SHA512.
  def sha512(content)
    require 'digest/sha2'
    Digest::SHA512.hexdigest(content)
  end

  def sha512?(string)
    string =~ /^\h{128}$/
  end

  def sha512_file(filename, lite = false)
    require 'digest/sha2'

    digest = Digest::SHA512.new
    checksum_file(digest, filename,  lite)
  end

  def sha512_stream(lite = false, &block)
    require 'digest/sha2'
    digest = Digest::SHA512.new
    checksum_stream(digest, block, lite)
  end

  def sha512_hex_length
    128
  end

  # Calculate a checksum using Digest::SHA224.
  def sha224(content)
    require 'openssl'
    OpenSSL::Digest::SHA224.new.hexdigest(content)
  end

  def sha224?(string)
    string =~ /^\h{56}$/
  end

  def sha224_file(filename, lite = false)
    require 'openssl'

    digest = OpenSSL::Digest::SHA224.new
    checksum_file(digest, filename,  lite)
  end

  def sha224_stream(lite = false, &block)
    require 'openssl'
    digest = OpenSSL::Digest::SHA224.new
    checksum_stream(digest, block, lite)
  end

  def sha224_hex_length
    56
  end

  # Calculate a checksum using Digest::MD5.
  def md5(content)
    Digest::MD5.hexdigest(content)
  end

  def md5?(string)
    string =~ /^\h{32}$/
  end

  # Calculate a checksum of a file's content using Digest::MD5.
  def md5_file(filename, lite = false)
    digest = Digest::MD5.new
    checksum_file(digest, filename,  lite)
  end

  def md5_stream(lite = false, &block)
    digest = Digest::MD5.new
    checksum_stream(digest, block, lite)
  end

  def md5_hex_length
    32
  end

  # Calculate a checksum of the first 500 chars of the content using Digest::MD5.
  def md5lite(content)
    md5(content[0..511])
  end

  def md5lite?(string)
    md5?(string)
  end

  # Calculate a checksum of the first 500 chars of a file's content using Digest::MD5.
  def md5lite_file(filename)
    md5_file(filename, true)
  end

  def md5lite_stream(&block)
    md5_stream(true, &block)
  end

  def md5lite_hex_length
    md5_hex_length
  end

  def mtime(content)
    ""
  end

  def mtime?(string)
    return true if string.is_a? Time
    !!DateTime.parse(string)
  rescue
    false
  end

  # Return the :mtime timestamp of a file.
  def mtime_file(filename)
    Puppet::FileSystem.stat(filename).send(:mtime)
  end

  # by definition this doesn't exist
  # but we still need to execute the block given
  def mtime_stream(&block)
    noop_digest = FakeChecksum.new
    yield noop_digest
    nil
  end

  # Calculate a checksum using Digest::SHA1.
  def sha1(content)
    Digest::SHA1.hexdigest(content)
  end

  def sha1?(string)
    string =~ /^\h{40}$/
  end

  # Calculate a checksum of a file's content using Digest::SHA1.
  def sha1_file(filename, lite = false)
    digest = Digest::SHA1.new
    checksum_file(digest, filename, lite)
  end

  def sha1_stream(lite = false, &block)
    digest = Digest::SHA1.new
    checksum_stream(digest, block, lite)
  end

  def sha1_hex_length
    40
  end

  # Calculate a checksum of the first 500 chars of the content using Digest::SHA1.
  def sha1lite(content)
    sha1(content[0..511])
  end

  def sha1lite?(string)
    sha1?(string)
  end

  # Calculate a checksum of the first 500 chars of a file's content using Digest::SHA1.
  def sha1lite_file(filename)
    sha1_file(filename, true)
  end

  def sha1lite_stream(&block)
    sha1_stream(true, &block)
  end

  def sha1lite_hex_length
    sha1_hex_length
  end

  def ctime(content)
    ""
  end

  def ctime?(string)
    return true if string.is_a? Time
    !!DateTime.parse(string)
  rescue
    false
  end

  # Return the :ctime of a file.
  def ctime_file(filename)
    Puppet::FileSystem.stat(filename).send(:ctime)
  end

  def ctime_stream(&block)
    mtime_stream(&block)
  end

  def none(content)
    ""
  end

  def none?(string)
    string.empty?
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

  class DigestLite
    def initialize(digest, lite = false)
      @digest = digest
      @lite = lite
      @bytes = 0
    end

    # Provide an interface for digests. If lite, only digest the first 512 bytes
    def <<(str)
      if @lite
        if @bytes < 512
          buf = str[0, 512 - @bytes]
          @digest << buf
          @bytes += buf.length
        end
      else
        @digest << str
      end
    end
  end

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

  def checksum_stream(digest, block, lite = false)
    block.call(DigestLite.new(digest, lite))
    digest.hexdigest
  end

end
