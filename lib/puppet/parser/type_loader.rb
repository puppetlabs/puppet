require 'puppet/node/environment'

class Puppet::Parser::TypeLoader
  include Puppet::Node::Environment::Helper

  class Helper < Hash
    include MonitorMixin
    def done_with(item)
      synchronize do
        delete(item)[:busy].signal if self.has_key?(item) and self[item][:loader] == Thread.current
      end
    end
    def owner_of(item)
      synchronize do
        if !self.has_key? item
          self[item] = { :loader => Thread.current, :busy => self.new_cond}
          :nobody
        elsif self[item][:loader] == Thread.current
          :this_thread
        else
          flag = self[item][:busy]
          flag.wait
          flag.signal
          :another_thread
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
      unless imported? file
        @imported[file] = true
        parse_file(file)
      end
    end

    modname
  end

  def imported?(file)
    @imported.has_key?(file)
  end

  def known_resource_types
    environment.known_resource_types
  end

  def initialize(env)
    self.environment = env
    @loaded = {}
    @loading = Helper.new

    @imported = {}
  end

  # Try to load the object with the given fully qualified name.  For
  # each file that was actually loaded, yield(filename, modname).
  def try_load_fqname(fqname)
    return nil if fqname == "" # special-case main.
    name2files(fqname).each do |filename|
      if not loaded?(filename)
        modname = begin
          import_if_possible(filename)
        rescue Puppet::ImportError => detail
          # We couldn't load the item
          # I'm not convienced we should just drop these errors, but this
          # preserves existing behaviours.
          nil
        end
        yield(filename, modname)
      end
    end
  end

  def loaded?(name)
    @loaded.include?(name)
  end

  def parse_file(file)
    Puppet.debug("importing '#{file}' in environment #{environment}")
    parser = Puppet::Parser::Parser.new(environment)
    parser.file = file
    parser.parse
  end

  # Utility method factored out of load for handling thread-safety.
  # This isn't tested in the specs, because that's basically impossible.
  def import_if_possible(file, current_file = nil)
    @loaded[file] || begin
      case @loading.owner_of(file)
      when :this_thread
        nil
      when :another_thread
        import_if_possible(file,current_file)
      when :nobody
        @loaded[file] = import(file,current_file)
      end
    ensure
      @loading.done_with(file)
    end
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
