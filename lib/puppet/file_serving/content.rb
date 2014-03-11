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
    [:raw]
  end

  def self.from_raw(content)
    instance = new("/this/is/a/fake/path")
    instance.content = content
    instance
  end

  # BF: we used to fetch the file content here, but this is counter-productive
  # for puppetmaster streaming of file content. So collect just returns itself
  def collect(source_permissions = nil)
    return if stat.ftype == "directory"
    self
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

  def to_raw
    File.new(full_path, "rb")
  end
end
