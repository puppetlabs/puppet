require 'puppet/file_bucket'
require 'puppet/indirector'
require 'puppet/util/checksums'

class Puppet::FileBucket::File
  include Puppet::Util::Checksums

  # This class handles the abstract notion of a file in a filebucket.
  # There are mechanisms to save and load this file locally and remotely in puppet/indirector/filebucketfile/*
  # There is a compatibility class that emulates pre-indirector filebuckets in Puppet::FileBucket::Dipper
  extend Puppet::Indirector
  require 'puppet/file_bucket/file/indirection_hooks'
  indirects :file_bucket_file, :terminus_class => :file, :extend => Puppet::FileBucket::File::IndirectionHooks

  attr :path, true
  attr :paths, true
  attr :contents, true
  attr :checksum_type
  attr :bucket_path, true

  def self.default_checksum_type
    "md5"
  end

  def initialize( contents, options = {} )
    @bucket_path   = options[:bucket_path]
    @path          = options[:path]
    @paths         = options[:paths] || []

    @checksum      = options[:checksum]
    @checksum_type = options[:checksum_type]

    self.contents  = contents

    yield(self) if block_given?

    validate!
  end

  def validate!
    validate_checksum_type!(checksum_type)
    validate_checksum!(checksum) if checksum
  end

  def contents=(str)
    raise "You may not change the contents of a FileBucket File" if @contents
    validate_content!(str)
    @contents = str
  end

  def checksum
    return @checksum if @checksum
    @checksum = calculate_checksum if contents
    @checksum
  end

  def checksum=(checksum)
    validate_checksum!(checksum)
    @checksum = checksum
  end

  def checksum_type=( new_checksum_type )
    @checksum = nil
    @checksum_type = new_checksum_type
  end

  def checksum_type
    unless @checksum_type
      if @checksum
        @checksum_type = sumtype(checksum)
      else
        @checksum_type = self.class.default_checksum_type
      end
    end
    @checksum_type
  end

  def checksum_data
    sumdata(checksum)
  end

  def to_s
    contents
  end

  def name
    [checksum_type, checksum_data, path].compact.join('/')
  end

  def name=(name)
    data = name.split('/',3)
    self.path = data.pop
    @checksum_type = nil
    self.checksum = "{#{data[0]}}#{data[1]}"
  end

  def conflict_check?
    true
  end

  def self.from_s( contents )
    self.new( contents )
  end

  def to_pson
    hash = { "contents" => contents }
    hash["path"] = @path if @path
    hash.to_pson
  end

  def self.from_pson( pson )
    self.new( pson["contents"], :path => pson["path"] )
  end

  private

  def calculate_checksum
    "{#{checksum_type}}" + send(checksum_type, contents)
  end

  def validate_content!(content)
    raise ArgumentError, "Contents must be a string" if content and ! content.is_a?(String)
  end

  def validate_checksum!(new_checksum)
    newtype = sumtype(new_checksum)

    unless sumdata(new_checksum) == (calc_sum = send(newtype, contents))
      raise Puppet::Error, "Checksum #{new_checksum} does not match contents #{calc_sum}"
    end
  end

  def validate_checksum_type!(type)
    raise ArgumentError, "Invalid checksum type #{type}" unless respond_to?(type)
  end
end
