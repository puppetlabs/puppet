# Autoload paths, either based on names or all at once.
class Puppet::Util::Autoload
    include Puppet::Util

    @autoloaders = {}
    @loaded = {}

    class << self
        attr_reader :autoloaders
        private :autoloaders
    end

    # Send [], []=, and :clear to the @autloaders hash
    Puppet::Util.classproxy self, :autoloaders, "[]", "[]="

    # Clear the list of autoloaders and loaded files.
    def self.clear
        @autoloaders.clear
        @loaded.clear
    end

    # List all loaded files.
    def self.list_loaded
        @loaded.sort { |a,b| a[0] <=> b[0] }.collect do |path, hash|
            "%s: %s" % [path, hash[:file]]
        end
    end

    # Has a given path been loaded?  This is used for testing whether a
    # changed file should be loaded or just ignored.
    def self.loaded?(path)
        path = path.to_s.sub(/\.rb$/, '')
        @loaded[path]
    end

    # Save the fact that a given path has been loaded
    def self.loaded(path, file, loader)
        @loaded[path] = {:file => file, :autoloader => loader}
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
        path = name.to_s + ".rb"

        eachdir do |dir|
            file = File.join(dir, path)
            next unless FileTest.exists?(file)
            begin
                Kernel.load file, @wrap
                name = symbolize(name)
                loaded name, file
                return true
            rescue LoadError => detail
                # I have no idea what's going on here, but different versions
                # of ruby are raising different errors on missing files.
                unless detail.to_s =~ /^no such file/i
                    warn "Could not autoload %s: %s" % [name, detail]
                    if Puppet[:trace]
                        puts detail.backtrace
                    end
                end
                return false
            end
        end
        return false
    end

    # Mark the named object as loaded.  Note that this supports unqualified
    # queries, while we store the result as a qualified query in the class.
    def loaded(name, file)
        self.class.loaded(File.join(@path, name.to_s), file, object)
    end

    # Indicate whether the specfied plugin has been loaded.
    def loaded?(name)
        self.class.loaded?(File.join(@path, name.to_s))
    end

    # Load all instances that we can.  This uses require, rather than load,
    # so that already-loaded files don't get reloaded unnecessarily.
    def loadall
        # Load every instance of everything we can find.
        eachdir do |dir|
            Dir.glob("#{dir}/*.rb").each do |file|
                # Load here, rather than require, so that facts
                # can be reloaded.  This has some short-comings, I
                # believe, but it works as long as real classes
                # aren't used.
                name = File.basename(file).sub(".rb", '').intern
                next if loaded?(name)
                next if $".include?(File.join(@path, name.to_s + ".rb"))
                filepath = File.join(@path, name.to_s + ".rb")
                begin
                    Kernel.require file
                    loaded(name, file)
                rescue => detail
                    if Puppet[:trace]
                        puts detail.backtrace
                    end
                    warn "Could not autoload %s: %s" % [file.inspect, detail]
                end
            end
        end
    end

    private

    # Yield each subdir in turn.
    def eachdir
        searchpath.each do |dir|
            subdir = File.join(dir, @path)
            yield subdir if FileTest.directory?(subdir)
        end
    end

    # The list of directories to search through for loadable plugins.
    def searchpath
        # JJM: Search for optional lib directories in each module bundle.
        module_lib_dirs = Puppet[:modulepath].split(":").collect do |d|
            Dir.glob("%s/*/lib" % d).select do |f|
                FileTest.directory?(f) 
            end
        end.flatten
        [module_lib_dirs, Puppet[:libdir], $:].flatten
    end
end
