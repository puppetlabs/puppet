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

    files.each do |file|
      unless file =~ /^#{File::SEPARATOR}/
        file = File.join(dir, file)
      end
      @loading_helper.do_once(file) do
        parse_file(file)
      end
    end

    modname
  end

  def known_resource_types
    environment.known_resource_types
  end

  def initialize(env)
    self.environment = env
    @loading_helper = Helper.new
  end

  def load_until(namespaces, name)
    return nil if name == "" # special-case main.
    name2files(namespaces, name).each do |filename|
      modname = begin
        import(filename)
      rescue Puppet::ImportError => detail
        # We couldn't load the item
        # I'm not convienced we should just drop these errors, but this
        # preserves existing behaviours.
        nil
      end
      if result = yield(filename)
        Puppet.debug "Automatically imported #{name} from #{filename} into #{environment}"
        result.module_name = modname if modname and result.respond_to?(:module_name=)
        return result
      end
    end
    nil
  end

  def name2files(namespaces, name)
    return [name.sub(/^::/, '').gsub("::", File::SEPARATOR)] if name =~ /^::/

    result = namespaces.inject([]) do |names_to_try, namespace|
      fullname = (namespace + "::#{name}").sub(/^::/, '')

      # Try to load the module init file if we're a qualified name
      names_to_try << fullname.split("::")[0] if fullname.include?("::")

      # Then the fully qualified name
      names_to_try << fullname
    end

    # Otherwise try to load the bare name on its own.  This
    # is appropriate if the class we're looking for is in a
    # module that's different from our namespace.
    result << name
    result.uniq.collect { |f| f.gsub("::", File::SEPARATOR) }
  end

  def parse_file(file)
    Puppet.debug("importing '#{file}' in environment #{environment}")
    parser = Puppet::Parser::Parser.new(environment)
    parser.file = file
    parser.parse
  end
end
