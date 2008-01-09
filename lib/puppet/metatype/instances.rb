require 'puppet/transportable'

class Puppet::Type
    # Make 'new' private, so people have to use create instead.
    class << self
        private :new
    end

    # retrieve a named instance of the current type
    def self.[](name)
        raise "Global resource access is deprecated"
        @objects[name] || @aliases[name]
    end

    # add an instance by name to the class list of instances
    def self.[]=(name,object)
        raise "Global resource storage is deprecated"
        newobj = nil
        if object.is_a?(Puppet::Type)
            newobj = object
        else
            raise Puppet::DevError, "must pass a Puppet::Type object"
        end

        if exobj = @objects[name] and self.isomorphic?
            msg = "Object '%s[%s]' already exists" %
                [newobj.class.name, name]

            if exobj.file and exobj.line
                msg += ("in file %s at line %s" %
                    [object.file, object.line])
            end
            if object.file and object.line
                msg += ("and cannot be redefined in file %s at line %s" %
                    [object.file, object.line])
            end
            error = Puppet::Error.new(msg)
            raise error
        else
            #Puppet.info("adding %s of type %s to class list" %
            #    [name,object.class])
            @objects[name] = newobj
        end
    end

    # Create an alias.  We keep these in a separate hash so that we don't encounter
    # the objects multiple times when iterating over them.
    def self.alias(name, obj)
        raise "Global resource aliasing is deprecated"
        if @objects.include?(name)
            unless @objects[name] == obj
                raise Puppet::Error.new(
                    "Cannot create alias %s: object already exists" %
                    [name]
                )
            end
        end

        if @aliases.include?(name)
            unless @aliases[name] == obj
                raise Puppet::Error.new(
                    "Object %s already has alias %s" %
                    [@aliases[name].name, name]
                )
            end
        end

        @aliases[name] = obj
    end

    # remove all of the instances of a single type
    def self.clear
        raise "Global resource removal is deprecated"
        if defined? @objects
            @objects.each do |name, obj|
                obj.remove(true)
            end
            @objects.clear
        end
        if defined? @aliases
            @aliases.clear
        end
    end

    # Force users to call this, so that we can merge objects if
    # necessary.
    def self.create(args)
        # Don't modify the original hash; instead, create a duplicate and modify it.
        # We have to dup and use the ! so that it stays a TransObject if it is
        # one.
        hash = args.dup
        symbolizehash!(hash)

        # If we're the base class, then pass the info on appropriately
        if self == Puppet::Type
            type = nil
            if hash.is_a? Puppet::TransObject
                type = hash.type
            else
                # If we're using the type to determine object type, then delete it
                if type = hash[:type]
                    hash.delete(:type)
                end
            end

            # If they've specified a type and called on the base, then
            # delegate to the subclass.
            if type
                if typeklass = self.type(type)
                    return typeklass.create(hash)
                else
                    raise Puppet::Error, "Unknown type %s" % type
                end
            else
                raise Puppet::Error, "No type found for %s" % hash.inspect
            end
        end

        # Handle this new object being implicit
        implicit = hash[:implicit] || false
        if hash.include?(:implicit)
            hash.delete(:implicit)
        end

        name = nil
        unless hash.is_a? Puppet::TransObject
            hash = self.hash2trans(hash)
        end

        # XXX This will have to change when transobjects change to using titles
        title = hash.name

        # create it anew
        # if there's a failure, destroy the object if it got that far, but raise
        # the error.
        begin
            obj = new(hash)
        rescue => detail
            Puppet.err "Could not create %s: %s" % [title, detail.to_s]
            if obj
                obj.remove(true)
            end
            raise
        end

        if implicit
            obj.implicit = true
        end

        return obj
    end

    # remove a specified object
    def self.delete(resource)
        raise "Global resource removal is deprecated"
        return unless defined? @objects
        if @objects.include?(resource.title)
            @objects.delete(resource.title)
        end
        if @aliases.include?(resource.title)
            @aliases.delete(resource.title)
        end
        if @aliases.has_value?(resource)
            names = []
            @aliases.each do |name, otherres|
                if otherres == resource
                    names << name
                end
            end
            names.each { |name| @aliases.delete(name) }
        end
    end

    # iterate across each of the type's instances
    def self.each
        raise "Global resource iteration is deprecated"
        return unless defined? @objects
        @objects.each { |name,instance|
            yield instance
        }
    end

    # does the type have an object with the given name?
    def self.has_key?(name)
        raise "Global resource access is deprecated"
        return @objects.has_key?(name)
    end

    # Convert a hash to a TransObject.
    def self.hash2trans(hash)
        title = nil
        if hash.include? :title
            title = hash[:title]
            hash.delete(:title)
        elsif hash.include? self.namevar
            title = hash[self.namevar]
            hash.delete(self.namevar)

            if hash.include? :name
                raise ArgumentError, "Cannot provide both name and %s to %s" %
                    [self.namevar, self.name]
            end
        elsif hash[:name]
            title = hash[:name]
            hash.delete :name
        end

        if catalog = hash[:catalog]
            hash.delete(:catalog)
        end

        raise(Puppet::Error, "You must specify a title for objects of type %s" % self.to_s) unless title

        if hash.include? :type
            unless self.validattr? :type
                hash.delete :type
            end
        end

        # okay, now make a transobject out of hash
        begin
            trans = Puppet::TransObject.new(title, self.name.to_s)
            trans.catalog = catalog if catalog
            hash.each { |param, value|
                trans[param] = value
            }
        rescue => detail
            raise Puppet::Error, "Could not create %s: %s" %
                [name, detail]
        end

        return trans
    end

    # Retrieve all known instances.  Either requires providers or must be overridden.
    def self.instances
        unless defined?(@providers) and ! @providers.empty?
            raise Puppet::DevError, "%s has no providers and has not overridden 'instances'" % self.name
        end

        # Put the default provider first, then the rest of the suitable providers.
        provider_instances = {}
        providers_by_source.collect do |provider|
            provider.instances.collect do |instance|
                # We always want to use the "first" provider instance we find, unless the resource
                # is already managed and has a different provider set
                if other = provider_instances[instance.name]
                    Puppet.warning "%s %s found in both %s and %s; skipping the %s version" %
                        [self.name.to_s.capitalize, instance.name, other.class.name, instance.class.name, instance.class.name]
                    next
                end
                provider_instances[instance.name] = instance

                create(:name => instance.name, :provider => instance, :check => :all)
            end
        end.flatten.compact
    end

    # Return a list of one suitable provider per source, with the default provider first.
    def self.providers_by_source
        # Put the default provider first, then the rest of the suitable providers.
        sources = []
        [defaultprovider, suitableprovider].flatten.uniq.collect do |provider|
            next if sources.include?(provider.source)

            sources << provider.source
            provider
        end.compact
    end

    # Create the path for logging and such.
    def pathbuilder
        if p = parent
            [p.pathbuilder, self.ref].flatten
        else
            [self.ref]
        end
    end
end

