# The container class for implementations.
class Puppet::Provider
    include Puppet::Util

    Puppet::Util.logmethods(self, true)

    class << self
        # Include the util module so we have access to things like 'binary'
        include Puppet::Util, Puppet::Util::Docs
        attr_accessor :name, :model
        attr_writer :doc
    end

    attr_accessor :model
    
    def self.command(name)
        name = symbolize(name)

        if command = @commands[name]
            # nothing
        elsif superclass.respond_to? :command and command = superclass.command(name)
            # nothing
        else
            raise Puppet::DevError, "No command %s defined for provider %s" %
                [name, self.name]
        end

        unless command =~ /^\//
            raise Puppet::Error, "Command #{command} could not be found"
        end
    end

    # Define one or more binaries we'll be using
    def self.commands(hash)
        hash.each do |name, path|
            name = symbolize(name)
            @origcommands[name] = path
            # Keep the short name if we couldn't find it.
            unless path =~ /^\//
                if tmp = binary(path)
                    path = tmp
                end
            end
            @commands[name] = path
            confine :exists => path
        end
    end

    def self.confine(hash)
        hash.each do |p,v|
            if v.is_a? Array
                @confines[p] += v
            else
                @confines[p] << v
            end
        end
    end

    # Does this implementation match all of the default requirements?
    def self.default?
        if @defaults.find do |fact, value|
                Facter[fact].value.to_s.downcase.intern != value.to_s.downcase.intern
            end
            return false
        else
            return true
        end
    end

    # Store how to determine defaults.
    def self.defaultfor(hash)
        hash.each do |d,v|
            @defaults[d] = v
        end
    end

    def self.defaultnum
        @defaults.length
    end

    dochook(:defaults) do
        if @defaults.length > 0
            return "  Default for " + @defaults.collect do |f, v|
                "``#{f}`` == ``#{v}``"
            end.join(" and ") + "."
        end
    end

    dochook(:commands) do
        if @origcommands.length > 0
            return "  Required binaries: " + @origcommands.collect do |n, c|
                "``#{c}``"
            end.join(", ") + "."
        end
    end

    def self.initvars
        @defaults = {}
        @commands = {}
        @origcommands = {}
        @confines = Hash.new do |hash, key|
            hash[key] = []
        end
    end

    self.initvars

    # Check whether this implementation is suitable for our platform.
    def self.suitable?
        # A single false result is sufficient to turn the whole thing down.
        @confines.each do |check, values|
            case check
            when :exists:
                values.each do |value|
                    unless value and FileTest.exists? value
                        return false
                    end
                end
            when :true:
                values.each do |v|
                    return false unless v
                end
            when :false:
                values.each do |v|
                    return false if v
                end
            else # Just delegate everything else to facter
                result = Facter.send(check).to_s.downcase.intern

                found = values.find do |v|
                    result == v.to_s.downcase.intern
                end
                return false unless found
            end
        end

        return true
    end

    def command(name)
        self.class.command(name)
    end

    def initialize(model)
        @model = model
    end

    def name
        @model.name
    end

    def to_s
        "%s(provider=%s)" % [@model.to_s, self.class.name]
    end
end

# $Id$
