# Autoload paths, either based on names or all at once.
class Puppet::Util::Autoload
    include Puppet::Util

    @autoloaders = {}

    attr_accessor :object, :path, :objwarn, :wrap


    class << self
        attr_reader :autoloaders
        private :autoloaders
    end
    Puppet::Util.classproxy self, :autoloaders, "[]", "[]=", :clear

    attr_reader :loaded
    private :loaded

    Puppet::Util.proxy self, :loaded, :clear

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

        @loaded = {}
    end

    # Load a single plugin by name.
    def load(name)
        path = name.to_s + ".rb"

        eachdir do |dir|
            file = File.join(dir, path)
            next unless FileTest.exists?(file)
            begin
                Kernel.load file, @wrap
                name = symbolize(name)
                @loaded[name] = true
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

    # Indicate whether the specfied plugin has been loaded.
    def loaded?(name)
        @loaded[symbolize(name)]
    end

    def loadall
        # Load every instance of everything we can find.
        eachdir do |dir|
            Dir.glob("#{dir}/*.rb").each do |file|
                # Load here, rather than require, so that facts
                # can be reloaded.  This has some short-comings, I
                # believe, but it works as long as real classes
                # aren't used.
                name = File.basename(file).sub(".rb", '').intern
                next if @loaded.include? name
                next if $".include?(File.join(@path, name.to_s + ".rb"))
                filepath = File.join(@path, name.to_s + ".rb")
                begin
                    Kernel.require filepath
                    @loaded[name] = true
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
        [Puppet[:libdir], $:].flatten
    end
end

# $Id$
