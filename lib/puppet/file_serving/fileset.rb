require 'find'
require 'puppet/file_serving'
require 'puppet/file_serving/metadata'

# Operate recursively on a path, returning a set of file paths.
class Puppet::FileServing::Fileset
  attr_reader :path, :ignore, :links
  attr_accessor :recurse, :recurselimit, :checksum_type

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
    if Puppet.features.microsoft_windows?
      # REMIND: UNC path
      path = path.chomp(File::SEPARATOR) unless path =~ /^[A-Za-z]:\/$/
    else
      path = path.chomp(File::SEPARATOR) unless path == File::SEPARATOR
    end
    raise ArgumentError.new("Fileset paths must be fully qualified: #{path}") unless Puppet::Util.absolute_path?(path)

    @path = path

    # Set our defaults.
    self.ignore = []
    self.links = :manage
    @recurse = false
    @recurselimit = :infinite

    if options.is_a?(Puppet::Indirector::Request)
      initialize_from_request(options)
    else
      initialize_from_hash(options)
    end

    raise ArgumentError.new("Fileset paths must exist") unless valid?(path)
    raise ArgumentError.new("Fileset recurse parameter must not be a number anymore, please use recurselimit") if @recurse.is_a?(Integer)
  end

  # Return a list of all files in our fileset.  This is different from the
  # normal definition of find in that we support specific levels
  # of recursion, which means we need to know when we're going another
  # level deep, which Find doesn't do.
  def files
    files = perform_recursion

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
    raise(ArgumentError, "Invalid :links value '#{links}'") unless [:manage, :follow].include?(links)
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
        raise ArgumentError, "Invalid option '#{option}'", $!.backtrace
      end
    end
  end

  def initialize_from_request(request)
    [:links, :ignore, :recurse, :recurselimit, :checksum_type].each do |param|
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

      Dir.entries(path).
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

    while entry = current_dirs.shift
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
