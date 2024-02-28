# frozen_string_literal: true

require_relative '../../puppet/file_serving'
require_relative '../../puppet/util'

# The base class for Content and Metadata; provides common
# functionality like the behaviour around links.
class Puppet::FileServing::Base
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

    if Puppet::Util::Platform.windows?
      # Replace multiple slashes as long as they aren't at the beginning of a filename
      full_path.gsub(%r{(./)/+}, '\1')
    else
      full_path.gsub(%r{//+}, '/')
    end
  end

  def initialize(path, links: nil, relative_path: nil, source: nil)
    self.path = path
    @links = :manage

    self.links = links if links
    self.relative_path = relative_path if relative_path
    self.source = source if source
  end

  # Determine how we deal with links.
  attr_reader :links

  def links=(value)
    value = value.to_sym
    value = :manage if value == :ignore
    # TRANSLATORS ':link', ':manage', ':follow' should not be translated
    raise(ArgumentError, _(":links can only be set to :manage or :follow")) unless [:manage, :follow].include?(value)

    @links = value
  end

  # Set our base path.
  attr_reader :path

  def path=(path)
    raise ArgumentError, _("Paths must be fully qualified") unless Puppet::FileServing::Base.absolute?(path)

    @path = path
  end

  # Set a relative path; this is used for recursion, and sets
  # the file's path relative to the initial recursion point.
  attr_reader :relative_path

  def relative_path=(path)
    raise ArgumentError, _("Relative paths must not be fully qualified") if Puppet::FileServing::Base.absolute?(path)

    @relative_path = path
  end

  # Stat our file, using the appropriate link-sensitive method.
  def stat
    @stat_method ||= self.links == :manage ? :lstat : :stat
    Puppet::FileSystem.send(@stat_method, full_path)
  end

  def to_data_hash
    {
      'path' => @path,
      'relative_path' => @relative_path,
      'links' => @links.to_s
    }
  end

  def self.absolute?(path)
    Puppet::Util.absolute_path?(path, :posix) || (Puppet::Util::Platform.windows? && Puppet::Util.absolute_path?(path, :windows))
  end
end
