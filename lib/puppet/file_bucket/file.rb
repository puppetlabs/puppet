require 'puppet/file_bucket'
require 'puppet/indirector'
require 'puppet/util/checksums'
require 'digest/md5'

class Puppet::FileBucket::File
  # This class handles the abstract notion of a file in a filebucket.
  # There are mechanisms to save and load this file locally and remotely in puppet/indirector/filebucketfile/*
  # There is a compatibility class that emulates pre-indirector filebuckets in Puppet::FileBucket::Dipper
  extend Puppet::Indirector
  require 'puppet/file_bucket/file/indirection_hooks'
  indirects :file_bucket_file, :terminus_class => :file, :extend => Puppet::FileBucket::File::IndirectionHooks

  attr :contents
  attr :bucket_path

  def initialize( contents, options = {} )
    raise ArgumentError if !contents.is_a?(String)
    @contents  = contents

    @bucket_path = options.delete(:bucket_path)
    raise ArgumentError if options != {}
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

  def self.from_s( contents )
    self.new( contents )
  end

  def to_pson
    { "contents" => contents }.to_pson
  end

  def self.from_pson( pson )
    self.new( pson["contents"] )
  end
end
