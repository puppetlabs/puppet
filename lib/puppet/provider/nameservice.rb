require 'puppet'

# This is the parent class of all NSS classes.  They're very different in
# their backend, but they're pretty similar on the front-end.  This class
# provides a way for them all to be as similar as possible.
class Puppet::Provider::NameService < Puppet::Provider
    class << self
        def autogen_default(param)
            if defined? @autogen_defaults
                return @autogen_defaults[symbolize(param)]
            else
                return nil
            end
        end

        def autogen_defaults(hash)
            @autogen_defaults ||= {}
            hash.each do |param, value|
                @autogen_defaults[symbolize(param)] = value
            end
        end

        def initvars
            @checks = {}
            super
        end

        def instances
            objects = []
            listbyname do |name|
                objects << new(:name => name, :ensure => :present)
            end

            objects
        end

        def option(name, option)
            name = name.intern if name.is_a? String
            if defined? @options and @options.include? name and @options[name].include? option
                return @options[name][option]
            else
                return nil
            end
        end

        def options(name, hash)
            unless resource_type.validattr?(name)
                raise Puppet::DevError, "%s is not a valid attribute for %s" %
                    [name, resource_type.name]
            end
            @options ||= {}
            @options[name] ||= {}

            # Set options individually, so we can call the options method
            # multiple times.
            hash.each do |param, value|
                @options[name][param] = value
            end
        end

        # List everything out by name.  Abstracted a bit so that it works
        # for both users and groups.
        def listbyname
            names = []
            Etc.send("set%sent" % section())
            begin
                while ent = Etc.send("get%sent" % section())
                    names << ent.name
                    if block_given?
                        yield ent.name
                    end
                end
            ensure
                Etc.send("end%sent" % section())
            end

            return names
        end

        def resource_type=(resource_type)
            super
            @resource_type.validproperties.each do |prop|
                next if prop == :ensure
                unless public_method_defined?(prop)
                    define_method(prop) { get(prop) || :absent}
                end
                unless public_method_defined?(prop.to_s + "=")
                    define_method(prop.to_s + "=") { |*vals| set(prop, *vals) }
                end
            end
        end

        # This is annoying, but there really aren't that many options,
        # and this *is* built into Ruby.
        def section
            unless defined? @resource_type
                raise Puppet::DevError,
                    "Cannot determine Etc section without a resource type"

            end

            if @resource_type.name == :group
                "gr"
            else
                "pw"
            end
        end

        def validate(name, value)
            name = name.intern if name.is_a? String
            if @checks.include? name
                block = @checks[name][:block]
                unless block.call(value)
                    raise ArgumentError, "Invalid value %s: %s" %
                        [value, @checks[name][:error]]
                end
            end
        end

        def verify(name, error, &block)
            name = name.intern if name.is_a? String
            @checks[name] = {:error => error, :block => block}
        end

        private

        def op(property)
            @ops[property.name] || ("-" + property.name)
        end
    end

    # Autogenerate a value.  Mostly used for uid/gid, but also used heavily
    # with DirectoryServices, because DirectoryServices is stupid.
    def autogen(field)
        field = symbolize(field)
        id_generators = {:user => :uid, :group => :gid}
        if id_generators[@resource.class.name] == field
            return autogen_id(field)
        else
            if value = self.class.autogen_default(field)
                return value
            elsif respond_to?("autogen_%s" % [field])
                return send("autogen_%s" % field)
            else
                return nil
            end
        end
    end

    # Autogenerate either a uid or a gid.  This is hard-coded: we can only
    # generate one field type per class.
    def autogen_id(field)
        highest = 0

        group = method = nil
        case @resource.class.name
        when :user; group = :passwd; method = :uid
        when :group; group = :group; method = :gid
        else
            raise Puppet::DevError, "Invalid resource name %s" % resource
        end

        # Make sure we don't use the same value multiple times
        if defined? @@prevauto
            @@prevauto += 1
        else
            Etc.send(group) { |obj|
                if obj.gid > highest
                    unless obj.send(method) > 65000
                        highest = obj.send(method)
                    end
                end
            }

            @@prevauto = highest + 1
        end

        return @@prevauto
    end

    def create
       if exists?
            info "already exists"
            # The object already exists
            return nil
        end

        begin
            execute(self.addcmd)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not create %s %s: %s" %
                [@resource.class.name, @resource.name, detail]
        end
    end

    def delete
        unless exists?
            info "already absent"
            # the object already doesn't exist
            return nil
        end

        begin
            execute(self.deletecmd)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not delete %s %s: %s" %
                [@resource.class.name, @resource.name, detail]
        end
    end

    def ensure
        if exists?
            :present
        else
            :absent
        end
    end

    # Does our object exist?
    def exists?
        if getinfo(true)
            return true
        else
            return false
        end
    end

    # Retrieve a specific value by name.
    def get(param)
        if hash = getinfo(false)
            return hash[param]
        else
            return nil
        end
    end

    # Retrieve what we can about our object
    def getinfo(refresh)
        if @objectinfo.nil? or refresh == true
            @etcmethod ||= ("get" + self.class.section().to_s + "nam").intern
            begin
                @objectinfo = Etc.send(@etcmethod, @resource[:name])
            rescue ArgumentError => detail
                @objectinfo = nil
            end
        end

        # Now convert our Etc struct into a hash.
        if @objectinfo
            return info2hash(@objectinfo)
        else
            return nil
        end
    end

    # The list of all groups the user is a member of.  Different
    # user mgmt systems will need to override this method.
    def groups
        groups = []

        # Reset our group list
        Etc.setgrent

        user = @resource[:name]

        # Now iterate across all of the groups, adding each one our
        # user is a member of
        while group = Etc.getgrent
            members = group.mem

            if members.include? user
                groups << group.name
            end
        end

        # We have to close the file, so each listing is a separate
        # reading of the file.
        Etc.endgrent

        groups.join(",")
    end

    # Convert the Etc struct into a hash.
    def info2hash(info)
        hash = {}
        self.class.resource_type.validproperties.each do |param|
            method = posixmethod(param)
            if info.respond_to? method
                hash[param] = info.send(posixmethod(param))
            end
        end

        return hash
    end

    def initialize(resource)
        super

        @objectinfo = nil
    end

    def set(param, value)
        self.class.validate(param, value)
        cmd = modifycmd(param, value)
        unless cmd.is_a?(Array)
            raise Puppet::DevError, "Nameservice command must be an array"
        end
        begin
            execute(cmd)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not set %s on %s[%s]: %s" % [param, @resource.class.name, @resource.name, detail]
        end
    end
end

