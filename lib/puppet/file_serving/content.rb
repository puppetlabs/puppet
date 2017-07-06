require 'puppet/indirector'
require 'puppet/file_serving'
require 'puppet/file_serving/base'

# A class that handles retrieving file contents.
# It only reads the file when its content is specifically
# asked for.
class Puppet::FileServing::Content < Puppet::FileServing::Base
  extend Puppet::Indirector
  indirects :file_content, :terminus_class => :selector

  attr_writer :content

  def self.supported_formats
    [:binary]
  end

  def self.from_binary(content)
    instance = new("/this/is/a/fake/path")
    instance.content = content
    instance
  end

  # This is no longer used, but is still called by the file server implementations when interacting
  # with their model abstraction.
  def collect(source_permissions = nil)
  end

  # Read the content of our file in.
  def content
    unless @content
      # This stat can raise an exception, too.
      raise(ArgumentError, "Cannot read the contents of links unless following links") if stat.ftype == "symlink"

      @content = Puppet::FileSystem.binread(full_path)
    end
    @content
  end

  def to_binary
    File.new(full_path, "rb")
  end
end
