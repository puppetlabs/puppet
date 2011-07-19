require 'puppet/node/environment'

class Puppet::Parser::TypeLoader
  include Puppet::Node::Environment::Helper

  # Helper class that makes sure we don't try to import the same file
  # more than once from either the same thread or different threads.
  class Helper
    include MonitorMixin
    def initialize
      super
      # These hashes are indexed by filename
      @state = {} # :doing or :done
      @thread = {} # if :doing, thread that's doing the parsing
      @cond_var = {} # if :doing, condition var that will be signaled when done.
    end

    # Execute the supplied block exactly once per file, no matter how
    # many threads have asked for it to run.  If another thread is
    # already executing it, wait for it to finish.  If this thread is
    # already executing it, return immediately without executing the
    # block.
    #
    # Note: the reason for returning immediately if this thread is
    # already executing the block is to handle the case of a circular
    # import--when this happens, we attempt to recursively re-parse a
    # file that we are already in the process of parsing.  To prevent
    # an infinite regress we need to simply do nothing when the
    # recursive import is attempted.
    def do_once(file)
      need_to_execute = synchronize do
        case @state[file]
        when :doing
          if @thread[file] != Thread.current
            @cond_var[file].wait
          end
          false
        when :done
          false
        else
          @state[file] = :doing
          @thread[file] = Thread.current
          @cond_var[file] = new_cond
          true
        end
      end
      if need_to_execute
        begin
          yield
        ensure
          synchronize do
            @state[file] = :done
            @thread.delete(file)
            @cond_var.delete(file).broadcast
          end
        end
      end
    end
  end

  # Import our files.
  def import(file, current_file = nil)
    return if Puppet[:ignoreimport]

    # use a path relative to the file doing the importing
    if current_file
      dir = current_file.sub(%r{[^/]+$},'').sub(/\/$/, '')
    else
      dir = "."
    end
    if dir == ""
      dir = "."
    end

    pat = file
    modname, files = Puppet::Parser::Files.find_manifests(pat, :cwd => dir, :environment => environment)
    if files.size == 0
      raise Puppet::ImportError.new("No file(s) found for import of '#{pat}'")
    end

    loaded_asts = []
    files.each do |file|
      regex = Puppet.features.microsoft_windows? ? /^[A-Za-z]:#{File::SEPARATOR}/ : /^#{File::SEPARATOR}/
      unless file =~ regex
        file = File.join(dir, file)
      end
      @loading_helper.do_once(file) do
        loaded_asts << parse_file(file)
      end
    end
    loaded_asts.inject([]) do |loaded_types, ast|
      loaded_types + known_resource_types.import_ast(ast, modname)
    end
  end

  def import_all
    require 'find'

    module_names = []
    # Collect the list of all known modules
    environment.modulepath.each do |path|
      Dir.chdir(path) do
        Dir.glob("*").each do |dir|
          next unless FileTest.directory?(dir)
          module_names << dir
        end
      end
    end

    module_names.uniq!
    # And then load all files from each module, but (relying on system
    # behavior) only load files from the first module of a given name.  E.g.,
    # given first/foo and second/foo, only files from first/foo will be loaded.
    module_names.each do |name|
      mod = Puppet::Module.new(name, environment)
      Find.find(File.join(mod.path, "manifests")) do |path|
        if path =~ /\.pp$/ or path =~ /\.rb$/
          import(path)
        end
      end
    end
  end

  def known_resource_types
    environment.known_resource_types
  end

  def initialize(env)
    self.environment = env
    @loading_helper = Helper.new
  end

  # Try to load the object with the given fully qualified name.
  def try_load_fqname(type, fqname)
    return nil if fqname == "" # special-case main.
    name2files(fqname).each do |filename|
      begin
        imported_types = import(filename)
        if result = imported_types.find { |t| t.type == type and t.name == fqname }
          Puppet.debug "Automatically imported #{fqname} from #{filename} into #{environment}"
          return result
        end
      rescue Puppet::ImportError => detail
        # We couldn't load the item
        # I'm not convienced we should just drop these errors, but this
        # preserves existing behaviours.
      end
    end
    # Nothing found.
    return nil
  end

  def parse_file(file)
    Puppet.debug("importing '#{file}' in environment #{environment}")
    parser = Puppet::Parser::Parser.new(environment)
    parser.file = file
    return parser.parse
  end

  private

  # Return a list of all file basenames that should be tried in order
  # to load the object with the given fully qualified name.
  def name2files(fqname)
    result = []
    ary = fqname.split("::")
    while ary.length > 0
      result << ary.join(File::SEPARATOR)
      ary.pop
    end
    return result
  end

end
