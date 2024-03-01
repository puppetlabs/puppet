# frozen_string_literal: true

# Utility methods for interacting with POSIX objects; mostly user and group
module Puppet::Util::POSIX
  # This is a list of environment variables that we will set when we want to override the POSIX locale
  LOCALE_ENV_VARS = ['LANG', 'LC_ALL', 'LC_MESSAGES', 'LANGUAGE',
                     'LC_COLLATE', 'LC_CTYPE', 'LC_MONETARY', 'LC_NUMERIC', 'LC_TIME']

  # This is a list of user-related environment variables that we will unset when we want to provide a pristine
  # environment for "exec" runs
  USER_ENV_VARS = ['HOME', 'USER', 'LOGNAME']

  class << self
    # Returns an array of all the groups that the user's a member of.
    def groups_of(user)
      begin
        require_relative '../../puppet/ffi/posix'
        groups = get_groups_list(user)
      rescue StandardError, LoadError => e
        Puppet.debug("Falling back to Puppet::Etc.group: #{e.message}")

        groups = []
        Puppet::Etc.group do |group|
          groups << group.name if group.mem.include?(user)
        end
      end

      uniq_groups = groups.uniq
      if uniq_groups != groups
        Puppet.debug(_('Removing any duplicate group entries'))
      end

      uniq_groups
    end

    private

    def get_groups_list(user)
      raise LoadError, "The 'getgrouplist' method is not available" unless Puppet::FFI::POSIX::Functions.respond_to?(:getgrouplist)

      user_gid = Puppet::Etc.getpwnam(user).gid
      ngroups = Puppet::FFI::POSIX::Constants::MAXIMUM_NUMBER_OF_GROUPS

      loop do
        FFI::MemoryPointer.new(:int) do |ngroups_ptr|
          FFI::MemoryPointer.new(:uint, ngroups) do |groups_ptr|
            old_ngroups = ngroups
            ngroups_ptr.write_int(ngroups)

            if Puppet::FFI::POSIX::Functions.getgrouplist(user, user_gid, groups_ptr, ngroups_ptr) != -1
              groups_gids = groups_ptr.get_array_of_uint(0, ngroups_ptr.read_int)

              result = []
              groups_gids.each do |group_gid|
                group_info = Puppet::Etc.getgrgid(group_gid)
                result |= [group_info.name] if group_info.mem.include?(user)
              end
              return result
            end

            ngroups = ngroups_ptr.read_int
            if ngroups <= old_ngroups
              ngroups *= 2
            end
          end
        end
      end
    end
  end

  # Retrieve a field from a POSIX Etc object.  The id can be either an integer
  # or a name.  This only works for users and groups.  It's also broken on
  # some platforms, unfortunately, which is why we fall back to the other
  # method search_posix_field in the gid and uid methods if a sanity check
  # fails
  def get_posix_field(space, field, id)
    raise Puppet::DevError, _("Did not get id from caller") unless id

    if id.is_a?(Integer)
      if id > Puppet[:maximum_uid].to_i
        Puppet.err _("Tried to get %{field} field for silly id %{id}") % { field: field, id: id }
        return nil
      end
      method = methodbyid(space)
    else
      method = methodbyname(space)
    end

    begin
      return Etc.send(method, id).send(field)
    rescue NoMethodError, ArgumentError
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
        Puppet.err _("Tried to get %{field} field for silly id %{id}") % { field: field, id: id }
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
    nil
  end

  # Determine what the field name is for users and groups.
  def idfield(space)
    case space.intern
    when :gr, :group; return :gid
    when :pw, :user, :passwd; return :uid
    else
      raise ArgumentError, _("Can only handle users and groups")
    end
  end

  # Determine what the method is to get users and groups by id
  def methodbyid(space)
    case space.intern
    when :gr, :group; return :getgrgid
    when :pw, :user, :passwd; return :getpwuid
    else
      raise ArgumentError, _("Can only handle users and groups")
    end
  end

  # Determine what the method is to get users and groups by name
  def methodbyname(space)
    case space.intern
    when :gr, :group; return :getgrnam
    when :pw, :user, :passwd; return :getpwnam
    else
      raise ArgumentError, _("Can only handle users and groups")
    end
  end

  # Get the GID
  def gid(group)
    get_posix_value(:group, :gid, group)
  end

  # Get the UID
  def uid(user)
    get_posix_value(:passwd, :uid, user)
  end

  private

  # Get the specified id_field of a given field (user or group),
  # whether an ID name is provided
  def get_posix_value(location, id_field, field)
    begin
      field = Integer(field)
    rescue ArgumentError
      # pass
    end
    if field.is_a?(Integer)
      name = get_posix_field(location, :name, field)
      return nil unless name

      id = get_posix_field(location, id_field, name)
      check_value = id
    else
      id = get_posix_field(location, id_field, field)
      return nil unless id

      name = get_posix_field(location, :name, id)
      check_value = name
    end

    if check_value != field
      check_value_id = get_posix_field(location, id_field, check_value) if check_value

      if id == check_value_id
        Puppet.debug("Multiple entries found for resource: '#{location}' with #{id_field}: #{id}")
        return id
      else
        Puppet.debug("The value retrieved: '#{check_value}' is different than the required state: '#{field}', searching in all entries")
        return search_posix_field(location, id_field, field)
      end
    else
      return id
    end
  end
end
