# frozen_string_literal: true
require 'find'
require_relative '../../puppet/file_serving'
require_relative '../../puppet/file_serving/metadata'

# Operate recursively on a path, returning a set of file paths.
class Puppet::FileServing::Fileset
  attr_reader :path, :ignore, :links
  attr_accessor :recurse, :recurselimit, :max_files, :checksum_type

  # Produce a hash of files, with merged so that earlier files
  # with the same postfix win.  E.g., /dir1/subfile beats /dir2/subfile.
  # It's a hash because we need to know the relative path of each file,
  # and the base directory.
  #   This will probably only ever be used for searching for plugins.
  def self.merge(*filesets)
    result = {}

    filesets.each do |fileset|
      fileset.files.each do |file|
        result[file] ||= fileset.path
      end
    end

    result
  end

  def initialize(path, options = {})
    if Puppet::Util::Platform.windows?
      # REMIND: UNC path
      path = path.chomp(File::SEPARATOR) unless path =~ /^[A-Za-z]:\/$/
    else
      path = path.chomp(File::SEPARATOR) unless path == File::SEPARATOR
    end
    raise ArgumentError.new(_("Fileset paths must be fully qualified: %{path}") % { path: path }) unless Puppet::Util.absolute_path?(path)

    @path = path

    # Set our defaults.
    self.ignore = []
    self.links = :manage
    @recurse = false
    @recurselimit = :infinite
    @max_files = 0

    if options.is_a?(Puppet::Indirector::Request)
      initialize_from_request(options)
    else
      initialize_from_hash(options)
    end

    raise ArgumentError.new(_("Fileset paths must exist")) unless valid?(path)
    #TRANSLATORS "recurse" and "recurselimit" are parameter names and should not be translated
    raise ArgumentError.new(_("Fileset recurse parameter must not be a number anymore, please use recurselimit")) if @recurse.is_a?(Integer)
  end

  # Return a list of all files in our fileset.  This is different from the
  # normal definition of find in that we support specific levels
  # of recursion, which means we need to know when we're going another
  # level deep, which Find doesn't do.
  def files
    files = perform_recursion
    soft_max_files = 1000

    # munged_max_files is needed since puppet http handler is keeping negative numbers as strings
    # https://github.com/puppetlabs/puppet/blob/main/lib/puppet/network/http/handler.rb#L196-L197
    munged_max_files = max_files == '-1' ? -1 : max_files

    if munged_max_files > 0 && files.size > munged_max_files
      raise Puppet::Error.new _("The directory '%{path}' contains %{entries} entries, which exceeds the limit of %{munged_max_files} specified by the max_files parameter for this resource. The limit may be increased, but be aware that large number of file resources can result in excessive resource consumption and degraded performance. Consider using an alternate method to manage large directory trees") % { path: path, entries: files.size, munged_max_files: munged_max_files }
    elsif munged_max_files == 0 && files.size > soft_max_files
      Puppet.warning _("The directory '%{path}' contains %{entries} entries, which exceeds the default soft limit %{soft_max_files} and may cause excessive resource consumption and degraded performance. To remove this warning set a value for `max_files` parameter or consider using an alternate method to manage large directory trees") % { path: path, entries: files.size, soft_max_files: soft_max_files }
    end

    # Now strip off the leading path, so each file becomes relative, and remove
    # any slashes that might end up at the beginning of the path.
    result = files.collect { |file| file.sub(%r{^#{Regexp.escape(@path)}/*}, '') }

    # And add the path itself.
    result.unshift(".")

    result
  end

  def ignore=(values)
    values = [values] unless values.is_a?(Array)
    @ignore = values.collect(&:to_s)
  end

  def links=(links)
    links = links.to_sym
    #TRANSLATORS ":links" is a parameter name and should not be translated
    raise(ArgumentError, _("Invalid :links value '%{links}'") % { links: links }) unless [:manage, :follow].include?(links)

    @links = links
    @stat_method = @links == :manage ? :lstat : :stat
  end

  private

  def initialize_from_hash(options)
    options.each do |option, value|
      method = option.to_s + "="
      begin
        send(method, value)
      rescue NoMethodError
        raise ArgumentError, _("Invalid option '%{option}'") % { option: option }, $!.backtrace
      end
    end
  end

  def initialize_from_request(request)
    [:links, :ignore, :recurse, :recurselimit, :max_files, :checksum_type].each do |param|
      if request.options.include?(param) # use 'include?' so the values can be false
        value = request.options[param]
      elsif request.options.include?(param.to_s)
        value = request.options[param.to_s]
      end
      next if value.nil?

      value = true if value == "true"
      value = false if value == "false"
      value = Integer(value) if value.is_a?(String) and value =~ /^\d+$/
      send(param.to_s + "=", value)
    end
  end

  FileSetEntry = Struct.new(:depth, :path, :ignored, :stat_method) do
    def down_level(to)
      FileSetEntry.new(depth + 1, File.join(path, to), ignored, stat_method)
    end

    def basename
      File.basename(path)
    end

    def children
      return [] unless directory?

      Dir.entries(path, encoding: Encoding::UTF_8).
        reject { |child| ignore?(child) }.
        collect { |child| down_level(child) }
    end

    def ignore?(child)
      return true if child == "." || child == ".."
      return false if ignored == [nil]

      ignored.any? { |pattern| File.fnmatch?(pattern, child) }
    end

    def directory?
      Puppet::FileSystem.send(stat_method, path).directory?
    rescue Errno::ENOENT, Errno::EACCES
      false
    end
  end

  # Pull the recursion logic into one place.  It's moderately hairy, and this
  # allows us to keep the hairiness apart from what we do with the files.
  def perform_recursion
    current_dirs = [FileSetEntry.new(0, @path, @ignore, @stat_method)]

    result = []

    while entry = current_dirs.shift #rubocop:disable Lint/AssignmentInCondition
      if continue_recursion_at?(entry.depth + 1)
        entry.children.each do |child|
          result << child.path
          current_dirs << child
        end
      end
    end

    result
  end

  def valid?(path)
    Puppet::FileSystem.send(@stat_method, path)
    true
  rescue Errno::ENOENT, Errno::EACCES
    false
  end

  def continue_recursion_at?(depth)
    # recurse if told to, and infinite recursion or current depth not at the limit
    self.recurse && (self.recurselimit == :infinite || depth <= self.recurselimit)
  end
end
