require 'puppet/file_serving'
require 'puppet/util'
require 'puppet/util/methodhelper'

# The base class for Content and Metadata; provides common
# functionality like the behaviour around links.
class Puppet::FileServing::Base
  include Puppet::Util::MethodHelper

  # This is for external consumers to store the source that was used
  # to retrieve the metadata.
  attr_accessor :source

  # Does our file exist?
  def exist?
      stat
      return true
  rescue
      return false
  end

  # Return the full path to our file.  Fails if there's no path set.
  def full_path
    if relative_path.nil? or relative_path == "" or relative_path == "."
      full_path = path
    else
      full_path = File.join(path, relative_path)
    end

    if Puppet.features.microsoft_windows?
      # Replace multiple slashes as long as they aren't at the beginning of a filename
      full_path.gsub(%r{(./)/+}, '\1')
    else
      full_path.gsub(%r{//+}, '/')
    end
  end

  def initialize(path, options = {})
    self.path = path
    @links = :manage
    set_options(options)
  end

  # Determine how we deal with links.
  attr_reader :links
  def links=(value)
    value = value.to_sym
    value = :manage if value == :ignore
    #TRANSLATORS ':link', ':manage', ':follow' should not be translated
    raise(ArgumentError, _(":links can only be set to :manage or :follow")) unless [:manage, :follow].include?(value)
    @links = value
  end

  # Set our base path.
  attr_reader :path
  def path=(path)
    raise ArgumentError.new(_("Paths must be fully qualified")) unless Puppet::FileServing::Base.absolute?(path)
    @path = path
  end

  # Set a relative path; this is used for recursion, and sets
  # the file's path relative to the initial recursion point.
  attr_reader :relative_path
  def relative_path=(path)
    raise ArgumentError.new(_("Relative paths must not be fully qualified")) if Puppet::FileServing::Base.absolute?(path)
    @relative_path = path
  end

  # Stat our file, using the appropriate link-sensitive method.
  def stat
    @stat_method ||= self.links == :manage ? :lstat : :stat
    Puppet::FileSystem.send(@stat_method, full_path)
  end

  def to_data_hash
    {
      'path'          => @path,
      'relative_path' => @relative_path,
      'links'         => @links.to_s
    }
  end

  def self.absolute?(path)
    Puppet::Util.absolute_path?(path, :posix) or (Puppet.features.microsoft_windows? and Puppet::Util.absolute_path?(path, :windows))
  end
end
