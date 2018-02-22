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
    [:binary]
  end

  def initialize(contents, options = {})
    case contents
    when String
      @contents = StringContents.new(contents)
    when Pathname
      @contents = FileContents.new(contents)
    else
      raise ArgumentError.new(_("contents must be a String or Pathname, got a %{contents_class}") % { contents_class: contents.class })
    end

    @bucket_path = options.delete(:bucket_path)
    @checksum_type = Puppet[:digest_algorithm].to_sym
    raise ArgumentError.new(_("Unknown option(s): %{opts}") % { opts: options.keys.join(', ') }) unless options.empty?
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
    to_binary
  end

  def to_binary
    @contents.to_binary
  end

  def contents
    to_binary
  end

  def name
    "#{checksum_type}/#{checksum_data}"
  end

  def self.from_binary(contents)
    self.new(contents)
  end

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
      Puppet.info(_("Computing checksum on string"))
      Puppet::Util::Checksums.method(base_method).call(@contents)
    end

    def to_binary
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
      Puppet.info(_("Computing checksum on file %{path}") % { path: @path })
      Puppet::Util::Checksums.method(:"#{base_method}_file").call(@path)
    end

    def to_binary
      Puppet::FileSystem::binread(@path)
    end
  end
end
