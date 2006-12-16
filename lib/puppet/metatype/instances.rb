class Puppet::Type
    # Make 'new' private, so people have to use create instead.
    class << self
        private :new
    end

    # retrieve a named instance of the current type
    def self.[](name)
        @objects[name] || @aliases[name]
    end

    # add an instance by name to the class list of instances
    def self.[]=(name,object)
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
    # necessary.  FIXME This method should be responsible for most of the
    # error handling.
    def self.create(args)
        # Don't modify the original hash; instead, create a duplicate and modify it.
        # We have to dup and use the ! so that it stays a TransObject if it is
        # one.
        hash = args.dup
        symbolizehash!(hash)

        # If we're the base class, then pass the info on appropriately
        if self == Puppet::Type
            type = nil
            if hash.is_a? TransObject
                type = hash.type
            else
                # If we're using the type to determine object type, then delete it
                if type = hash[:type]
                    hash.delete(:type)
                end
            end

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
        unless hash.is_a? TransObject
            hash = self.hash2trans(hash)
        end

        # XXX This will have to change when transobjects change to using titles
        title = hash.name

        #Puppet.debug "Creating %s[%s]" % [self.name, title]

        # if the object already exists
        if self.isomorphic? and retobj = self[title]
            # if only one of our objects is implicit, then it's easy to see
            # who wins -- the non-implicit one.
            if retobj.implicit? and ! implicit
                Puppet.notice "Removing implicit %s" % retobj.title
                # Remove all of the objects, but do not remove their subscriptions.
                retobj.remove(false)

                # now pass through and create the new object
            elsif implicit
                Puppet.notice "Ignoring implicit %s" % title

                return retobj
            else
                # If only one of the objects is being managed, then merge them
                if retobj.managed?
                    raise Puppet::Error, "%s '%s' is already being managed" %
                        [self.name, title]
                else
                    retobj.merge(hash)
                    return retobj
                end
                # We will probably want to support merging of some kind in
                # the future, but for now, just throw an error.
                #retobj.merge(hash)

                #return retobj
            end
        end

        # create it anew
        # if there's a failure, destroy the object if it got that far, but raise
        # the error.
        begin
            obj = new(hash)
        rescue => detail
            Puppet.err "Could not create %s: %s" % [title, detail.to_s]
            if obj
                obj.remove(true)
            elsif obj = self[title]
                obj.remove(true)
            end
            raise
        end

        if implicit
            obj.implicit = true
        end

        # Store the object by title
        self[obj.title] = obj

        return obj
    end

    # remove a specified object
    def self.delete(object)
        return unless defined? @objects
        if @objects.include?(object.title)
            @objects.delete(object.title)
        end
        if @aliases.include?(object.title)
            @aliases.delete(object.title)
        end
    end

    # iterate across each of the type's instances
    def self.each
        return unless defined? @objects
        @objects.each { |name,instance|
            yield instance
        }
    end

    # does the type have an object with the given name?
    def self.has_key?(name)
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

        unless title
            raise Puppet::Error,
                "You must specify a title for objects of type %s" % self.to_s
        end

        if hash.include? :type
            unless self.validattr? :type
                hash.delete :type
            end
        end
        # okay, now make a transobject out of hash
        begin
            trans = TransObject.new(title, self.name.to_s)
            hash.each { |param, value|
                trans[param] = value
            }
        rescue => detail
            raise Puppet::Error, "Could not create %s: %s" %
                [name, detail]
        end

        return trans
    end
end

# $Id$
