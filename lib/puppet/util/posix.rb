# Utility methods for interacting with POSIX objects; mostly user and group
module Puppet::Util::POSIX

    # Retrieve a field from a POSIX Etc object.  The id can be either an integer
    # or a name.  This only works for users and groups.  It's also broken on
    # some platforms, unfortunately.
    def old_get_posix_field(space, field, id)
        unless id
            raise ArgumentError, "Did not get id"
        end
        if id =~ /^\d+$/
            id = Integer(id)
        end
        prefix = "get" + space.to_s
        if id.is_a?(Integer)
            if id > 1000000
                Puppet.err "Tried to get %s field for silly id %s" % [field, id]
                return nil
            end
            method = (prefix + idfield(space).to_s).intern
        else
            method = (prefix + "nam").intern
        end

        begin
            return Etc.send(method, id).send(field)
        rescue ArgumentError => detail
            # ignore it; we couldn't find the object
            return nil
        end
    end

    # A degenerate method of retrieving name/id mappings.  The job of this method is
    # to find a specific entry and then return a given field from that entry.
    def get_posix_field(type, field, id)
        idmethod = idfield(type)
        integer = false
        if id =~ /^\d+$/
            id = Integer(id)
        end
        if id.is_a?(Integer)
            integer = true
            if id > 1000000
                Puppet.err "Tried to get %s field for silly id %s" % [field, id]
                return nil
            end
        end

        Etc.send(type) do |object|
            if integer and object.send(idmethod) == id
                return object.send(field)
            elsif object.name == id
                return object.send(field)
            end
        end

        # Apparently the group/passwd methods need to get reset; if we skip
        # this call, then new users aren't found.
        case type
        when :passwd: Etc.send(:endpwent)
        when :group: Etc.send(:endgrent)
        end
        return nil
    end
    
    # Determine what the field name is for users and groups.
    def idfield(space)
        case Puppet::Util.symbolize(space)
        when :gr, :group: return :gid
        when :pw, :user, :passwd: return :uid
        else
            raise ArgumentError.new("Can only handle users and groups")
        end
    end
    
    # Get the GID of a given group, provided either a GID or a name
    def gid(group)
        get_posix_field(:group, :gid, group)
    end

    # Get the UID of a given user, whether a UID or name is provided
    def uid(user)
        get_posix_field(:passwd, :uid, user)
    end
end

