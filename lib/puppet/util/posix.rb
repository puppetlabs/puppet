# Utility methods for interacting with POSIX objects; mostly user and group
module Puppet::Util::POSIX

    # Retrieve a field from a POSIX Etc object.  The id can be either an integer
    # or a name.  This only works for users and groups.  It's also broken on
    # some platforms, unfortunately, which is why we fall back to the other
    # method search_posix_field in the gid and uid methods if a sanity check
    # fails
    def get_posix_field(space, field, id)
        raise Puppet::DevError, "Did not get id from caller" unless id

        if id.is_a?(Integer)
            if id > Puppet[:maximum_uid].to_i
                Puppet.err "Tried to get %s field for silly id %s" % [field, id]
                return nil
            end
            method = methodbyid(space)
        else
            method = methodbyname(space)
        end

        begin
            return Etc.send(method, id).send(field)
        rescue ArgumentError => detail
            # ignore it; we couldn't find the object
            return nil
        end
    end

    # A degenerate method of retrieving name/id mappings.  The job of this method is
    # to retrieve all objects of a certain type, search for a specific entry
    # and then return a given field from that entry.
    def search_posix_field(type, field, id)
        idmethod = idfield(type)
        integer = false
        if id.is_a?(Integer)
            integer = true
            if id > Puppet[:maximum_uid].to_i
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
        when :passwd; Etc.send(:endpwent)
        when :group; Etc.send(:endgrent)
        end
        return nil
    end

    # Determine what the field name is for users and groups.
    def idfield(space)
        case Puppet::Util.symbolize(space)
        when :gr, :group; return :gid
        when :pw, :user, :passwd; return :uid
        else
            raise ArgumentError.new("Can only handle users and groups")
        end
    end

    # Determine what the method is to get users and groups by id
    def methodbyid(space)
        case Puppet::Util.symbolize(space)
        when :gr, :group; return :getgrgid
        when :pw, :user, :passwd; return :getpwuid
        else
            raise ArgumentError.new("Can only handle users and groups")
        end
    end

    # Determine what the method is to get users and groups by name
    def methodbyname(space)
        case Puppet::Util.symbolize(space)
        when :gr, :group; return :getgrnam
        when :pw, :user, :passwd; return :getpwnam
        else
            raise ArgumentError.new("Can only handle users and groups")
        end
    end

    # Get the GID of a given group, provided either a GID or a name
    def gid(group)
        begin
            group = Integer(group)
        rescue ArgumentError
            # pass
        end
        if group.is_a?(Integer)
            return nil unless name = get_posix_field(:group, :name, group)
            gid = get_posix_field(:group, :gid, name)
            check_value = gid
        else
            return nil unless gid = get_posix_field(:group, :gid, group)
            name = get_posix_field(:group, :name, gid)
            check_value = name
        end
        if check_value != group
            return search_posix_field(:group, :gid, group)
        else
            return gid
        end
    end

    # Get the UID of a given user, whether a UID or name is provided
    def uid(user)
        begin
            user = Integer(user)
        rescue ArgumentError
            # pass
        end
        if user.is_a?(Integer)
            return nil unless name = get_posix_field(:passwd, :name, user)
            uid = get_posix_field(:passwd, :uid, name)
            check_value = uid
        else
            return nil unless uid = get_posix_field(:passwd, :uid, user)
            name = get_posix_field(:passwd, :name, uid)
            check_value = name
        end
        if check_value != user
            return search_posix_field(:passwd, :uid, user)
        else
            return uid
        end
    end
end

