require 'puppet'

# This is the parent class of all NSS classes.  They're very different in
# their backend, but they're pretty similar on the front-end.  This class
# provides a way for them all to be as similar as possible.
class Puppet::Provider::NameService < Puppet::Provider
    class << self

        def list
            objects = []
            listbyname do |name|
                obj = nil
                check = model.validstates
                if obj = model[name]
                    obj[:check] = check
                else
                    # unless it exists, create it as an unmanaged object
                    obj = model.create(:name => name, :check => check)
                end

                next unless obj # In case there was an error somewhere
                
                objects << obj
                yield obj if block_given?
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
            unless model.validstate?(name)
                raise Puppet::DevError, "%s is not a valid state for %s" %
                    [name, model.name]
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

        # This is annoying, but there really aren't that many options,
        # and this *is* built into Ruby.
        def section
            unless defined? @model
                raise Puppet::DevError,
                    "Cannot determine Etc section without a model"

            end

            if @model.name == :group
                "gr"
            else
                "pw"
            end
        end

        def disabled_validate(name, value)
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
            @checks ||= {}
            @checks[name] = {:error => error, :block => block}
        end

        private

        def op(state)
            @ops[state.name] || ("-" + state.name)
        end
    end

    # Autogenerate either a uid or a gid.  This is hard-coded: we can only
    # generate one field type per class.
    def autogen
        highest = 0

        group = method = nil
        case @model.class.name
        when :user: group = :passwd; method = :uid
        when :group: group = :group; method = :gid
        else
            raise Puppet::DevError, "Invalid model name %s" % model
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

    def autogen_gid
        autogen(@model.class.name)
    end

    def autogen_uid
        autogen(@model.class.name)
    end

    def create
        self.ensure = :present
    end

    def delete
        self.ensure = :absent
    end

    def ensure
        if exists?
            :present
        else
            :absent
        end
    end

    # This is only used when creating or destroying the object.
    def ensure=(value)
        cmd = nil
        event = nil
        case value
        when :absent
            # we need to remove the object...
            unless exists?
                info "already absent"
                # the object already doesn't exist
                return nil
            end

            # again, needs to be set by the ind. state or its
            # parent
            cmd = self.deletecmd
            type = "delete"
        when :present
            if exists?
                info "already exists"
                # The object already exists
                return nil
            end

            # blah blah, define elsewhere, blah blah
            cmd = self.addcmd
            type = "create"
        end

        begin
            execute(cmd)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not %s %s %s: %s" %
                [type, @model.class.name, @model.name, detail]
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
                @objectinfo = Etc.send(@etcmethod, @model[:name])
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

        user = @model[:name]

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
        self.class.model.validstates.each do |param|
            method = posixmethod(param)
            if info.respond_to? method
                hash[param] = info.send(posixmethod(param))
            end
        end

        return hash
    end

    def initialize(model)
        super

        @objectinfo = nil
    end

    # 
    def method_missing(name, *args)
        name = name.to_s

        # Make sure it's a valid state.  We go up our class structure instead of
        # our model's because the model is fake during testing.
        unless self.class.model.validstate?(name.sub("=",''))
            raise Puppet::DevError, "%s is not a valid %s state" %
                [name, @model.class.name]
        end

        # Each class has to override this manually
        if name =~ /=/
            set(name.to_s.sub("=", ''), *args)
        else
            return get(name.intern) || :absent
        end
    end

    def set(param, value)
        #self.class.validate(param, value)
        cmd = modifycmd(param, value)
        begin
            execute(cmd)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not set %s on %s[%s]: %s" %
                [param, @model.class.name, @model.name, detail]
        end
    end
end

# $Id$
