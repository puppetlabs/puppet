require 'puppet/util/warnings'
require 'puppet/util/cacher'

# Autoload paths, either based on names or all at once.
class Puppet::Util::Autoload
    require 'puppet/util/autoload/file_cache'

    include Puppet::Util
    include Puppet::Util::Warnings
    include Puppet::Util::Cacher
    include Puppet::Util::Autoload::FileCache

    @autoloaders = {}
    @loaded = []

    class << self
        attr_reader :autoloaders
        private :autoloaders
    end

    # Send [], []=, and :clear to the @autloaders hash
    Puppet::Util.classproxy self, :autoloaders, "[]", "[]="

    # List all loaded files.
    def self.list_loaded
        @loaded.sort { |a,b| a[0] <=> b[0] }.collect do |path, hash|
            "%s: %s" % [path, hash[:file]]
        end
    end

    # Has a given path been loaded?  This is used for testing whether a
    # changed file should be loaded or just ignored.  This is only
    # used in network/client/master, when downloading plugins, to
    # see if a given plugin is currently loaded and thus should be
    # reloaded.
    def self.loaded?(path)
        path = path.to_s.sub(/\.rb$/, '')
        @loaded.include?(path)
    end

    # Save the fact that a given path has been loaded.  This is so
    # we can load downloaded plugins if they've already been loaded
    # into memory.
    def self.loaded(file)
        $" << file + ".rb" unless $".include?(file)
        @loaded << file unless @loaded.include?(file)
    end

    attr_accessor :object, :path, :objwarn, :wrap

    def initialize(obj, path, options = {})
        @path = path.to_s
        if @path !~ /^\w/
            raise ArgumentError, "Autoload paths cannot be fully qualified"
        end
        @object = obj

        self.class[obj] = self

        options.each do |opt, value|
            opt = opt.intern if opt.is_a? String
            begin
                self.send(opt.to_s + "=", value)
            rescue NoMethodError
                raise ArgumentError, "%s is not a valid option" % opt
            end
        end

        unless defined? @wrap
            @wrap = true
        end
    end

    # Load a single plugin by name.  We use 'load' here so we can reload a
    # given plugin.
    def load(name)
        return false if named_file_missing?(name)

        path = name.to_s + ".rb"

        searchpath.each do |dir|
            file = File.join(dir, path)
            next unless file_exist?(file)
            begin
                Kernel.load file, @wrap
                name = symbolize(name)
                loaded name, file
                return true
            rescue SystemExit,NoMemoryError
                raise
            rescue Exception => detail
                # I have no idea what's going on here, but different versions
                # of ruby are raising different errors on missing files.
                unless detail.to_s =~ /^no such file/i
                    warn "Could not autoload %s: %s" % [name, detail]
                    if Puppet[:trace]
                        puts detail.backtrace
                    end
                end
                return named_file_is_missing(name)
            end
        end
        return named_file_is_missing(name)
    end

    # Mark the named object as loaded.  Note that this supports unqualified
    # queries, while we store the result as a qualified query in the class.
    def loaded(name, file)
        self.class.loaded(File.join(@path, name.to_s))
    end

    # Indicate whether the specfied plugin has been loaded.
    def loaded?(name)
        self.class.loaded?(File.join(@path, name.to_s))
    end

    # Load all instances that we can.  This uses require, rather than load,
    # so that already-loaded files don't get reloaded unnecessarily.
    def loadall
        # Load every instance of everything we can find.
        searchpath.each do |dir|
            Dir.glob("#{dir}/*.rb").each do |file|
                name = File.basename(file).sub(".rb", '').intern
                next if loaded?(name)
                begin
                    Kernel.require file
                    loaded(name, file)
                rescue SystemExit,NoMemoryError
                    raise
                rescue Exception => detail
                    if Puppet[:trace]
                        puts detail.backtrace
                    end
                    warn "Could not autoload %s: %s" % [file.inspect, detail]
                end
            end
        end
    end

    # The list of directories to search through for loadable plugins.
    # We have to hard-code the ttl because this library is used by
    # so many other classes it's hard to get the load-order such that
    # the defaults load before this.
    cached_attr(:searchpath, :ttl => 15) do
        search_directories.collect { |d| File.join(d, @path) }.find_all { |d| FileTest.directory?(d) }
    end

    def module_directories
        # We have to require this late in the process because otherwise we might have
        # load order issues.
        require 'puppet/node/environment'
        Puppet::Node::Environment.new.modulepath.collect do |dir|
            Dir.entries(dir).reject { |f| f =~ /^\./ }.collect { |f| File.join(dir, f) }
        end.flatten.collect { |d| [File.join(d, "plugins"), File.join(d, "lib")] }.flatten.find_all do |d|
            FileTest.directory?(d)
        end
    end

    def search_directories(dummy_argument=:work_arround_for_ruby_GC_bug)
        [module_directories, Puppet[:libdir].split(File::PATH_SEPARATOR), $:].flatten
    end
end
