require 'puppet/file_bucket'
require 'puppet/indirector'
require 'puppet/util/checksums'
require 'digest/md5'

class Puppet::FileBucket::File
  # This class handles the abstract notion of a file in a filebucket.
  # There are mechanisms to save and load this file locally and remotely in puppet/indirector/filebucketfile/*
  # There is a compatibility class that emulates pre-indirector filebuckets in Puppet::FileBucket::Dipper
  extend Puppet::Indirector
  indirects :file_bucket_file, :terminus_class => :selector

  attr :contents
  attr :bucket_path

  def self.supported_formats
    # This should really be :raw, like is done for Puppet::FileServing::Content
    # but this class hasn't historically supported `from_raw`, so switching
    # would break compatibility between newer 3.x agents talking to older 3.x
    # masters. However, to/from_s has been supported and achieves the desired
    # result without breaking compatibility.
    [:s]
  end

  def initialize(contents, options = {})
    raise ArgumentError.new("contents must be a String, got a #{contents.class}") unless contents.is_a?(String)
    @contents = contents

    @bucket_path = options.delete(:bucket_path)
    raise ArgumentError.new("Unknown option(s): #{options.keys.join(', ')}") unless options.empty?
  end

  def checksum_type
    'md5'
  end

  def checksum
    "{#{checksum_type}}#{checksum_data}"
  end

  def checksum_data
    @checksum_data ||= Digest::MD5.hexdigest(contents)
  end

  def to_s
    contents
  end

  def name
    "#{checksum_type}/#{checksum_data}"
  end

  def self.from_s(contents)
    self.new(contents)
  end

  # This method is deprecated, but cannot be removed for awhile, otherwise
  # older agents sending pson couldn't backup to filebuckets on newer masters
  def self.from_pson(pson)
    Puppet.deprecation_warning("Deserializing Puppet::FileBucket::File objects from pson is deprecated. Upgrade to a newer version.")
    self.new(pson["contents"])
  end
end
