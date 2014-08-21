require 'puppet/file_bucket'
require 'puppet/indirector'
require 'puppet/util/checksums'
require 'digest/md5'
require 'stringio'

class Puppet::FileBucket::File
  # This class handles the abstract notion of a file in a filebucket.
  # There are mechanisms to save and load this file locally and remotely in puppet/indirector/filebucketfile/*
  # There is a compatibility class that emulates pre-indirector filebuckets in Puppet::FileBucket::Dipper
  extend Puppet::Indirector
  indirects :file_bucket_file, :terminus_class => :selector

  attr :bucket_path

  def self.supported_formats
    [:s, :pson]
  end

  def self.default_format
    # This should really be :raw, like is done for Puppet::FileServing::Content
    # but this class hasn't historically supported `from_raw`, so switching
    # would break compatibility between newer 3.x agents talking to older 3.x
    # masters. However, to/from_s has been supported and achieves the desired
    # result without breaking compatibility.
    :s
  end

  def initialize(contents, options = {})
    case contents
    when String
      @contents = StringContents.new(contents)
    when Pathname
      @contents = FileContents.new(contents)
    else
      raise ArgumentError.new("contents must be a String or Pathname, got a #{contents.class}")
    end

    @bucket_path = options.delete(:bucket_path)
    @checksum_type = Puppet[:digest_algorithm].to_sym
    raise ArgumentError.new("Unknown option(s): #{options.keys.join(', ')}") unless options.empty?
  end

  # @return [Num] The size of the contents
  def size
    @contents.size()
  end

  # @return [IO] A stream that reads the contents
  def stream(&block)
    @contents.stream(&block)
  end

  def checksum_type
    @checksum_type.to_s
  end

  def checksum
    "{#{checksum_type}}#{checksum_data}"
  end

  def checksum_data
    @checksum_data ||= @contents.checksum_data(@checksum_type)
  end

  def to_s
    @contents.to_s
  end

  def contents
    to_s
  end

  def name
    "#{checksum_type}/#{checksum_data}"
  end

  def self.from_s(contents)
    self.new(contents)
  end

  def to_data_hash
    # Note that this serializes the entire data to a string and places it in a hash.
    { "contents" => contents.to_s }
  end

  def self.from_data_hash(data)
    self.new(data["contents"])
  end

  def to_pson
    Puppet.deprecation_warning("Serializing Puppet::FileBucket::File objects to pson is deprecated.")
    to_data_hash.to_pson
  end

  # This method is deprecated, but cannot be removed for awhile, otherwise
  # older agents sending pson couldn't backup to filebuckets on newer masters
  def self.from_pson(pson)
    Puppet.deprecation_warning("Deserializing Puppet::FileBucket::File objects from pson is deprecated. Upgrade to a newer version.")
    self.from_data_hash(pson)
  end

  private

  class StringContents
    def initialize(content)
      @contents = content;
    end

    def stream(&block)
      s = StringIO.new(@contents)
      begin
        block.call(s)
      ensure
        s.close
      end
    end

    def size
      @contents.size
    end

    def checksum_data(base_method)
      Puppet.info("Computing checksum on string")
      Puppet::Util::Checksums.method(base_method).call(@contents)
    end

    def to_s
      # This is not so horrible as for FileContent, but still possible to mutate the content that the
      # checksum is based on... so semi horrible...
      return @contents;
    end
  end

  class FileContents
    def initialize(path)
      @path = path
    end

    def stream(&block)
      Puppet::FileSystem.open(@path, nil, 'rb', &block)
    end

    def size
      Puppet::FileSystem.size(@path)
    end

    def checksum_data(base_method)
      Puppet.info("Computing checksum on file #{@path}")
      Puppet::Util::Checksums.method(:"#{base_method}_file").call(@path)
    end

    def to_s
      Puppet::FileSystem::binread(@path)
    end
  end
end
