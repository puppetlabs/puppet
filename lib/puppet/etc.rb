require 'puppet/util/character_encoding'
# Wrapper around Ruby Etc module allowing us to manage encoding in a single
# place.
# This represents a subset of Ruby's Etc module, only the methods required by Puppet.

# On Ruby 2.1.0 and later, Etc returns strings in variable encoding depending on
# environment. The string returned will be labeled with the environment's
# encoding (Encoding.default_external), with one exception: If the environment
# encoding is 7-bit ASCII, and any individual character bit representation is
# equal to or greater than 128 - \x80 - 0b10000000 - signifying the smallest
# 8-bit big-endian value, the returned string will be in BINARY encoding instead
# of environment encoding.
#
# Barring that exception, the returned string will be labeled as encoding
# Encoding.default_external, regardless of validity or byte-width. For example,
# ruby will label a string containing a four-byte characters such as "\u{2070E}"
# as EUC_KR even though EUC_KR is a two-byte width encoding.
#
# On Ruby 2.0.x and earlier, Etc will always return string values in BINARY,
# ignoring encoding altogether.
#
# For Puppet we specifically want UTF-8 as our input from the Etc module - which
# is our input for many resource instance 'is' values. The associated 'should'
# value will basically always be coming from Puppet in UTF-8 - and written to
# disk as UTF-8. Etc is defined for Windows but the majority calls to it return
# nil and Puppet does not use it.
#
# That being said, we have cause to retain the original, pre-override string
# values. `puppet resource user`
# (Puppet::Resource::User.indirection.search('User', {})) uses self.instances to
# query for user(s) and then iterates over the results of that query again to
# obtain state for each user. If we've overridden the original user name and not
# retained the original, we've lost the ability to query the system for it
# later. Hence the Puppet::Etc::Passwd and Puppet::Etc::Group structs.
#
# We only use Etc for retrieving existing property values from the system. For
# setting property values, providers leverage system tools (i.e., `useradd`)
#
# @api private
module Puppet::Etc
  class << self

    # Etc::getgrent returns an Etc::Group struct object
    # On first call opens /etc/group and returns parse of first entry. Each subsquent call
    # returns new struct the next entry or nil if EOF. Call ::endgrent to close file.
    def getgrent
      override_field_values_to_utf8(::Etc.getgrent)
    end

    # closes handle to /etc/group file
    def endgrent
      ::Etc.endgrent
    end

    # effectively equivalent to IO#rewind of /etc/group
    def setgrent
      ::Etc.setgrent
    end

    # Etc::getpwent returns an Etc::Passwd struct object
    # On first call opens /etc/passwd and returns parse of first entry. Each subsquent call
    # returns new struct for the next entry or nil if EOF. Call ::endgrent to close file.
    def getpwent
      override_field_values_to_utf8(::Etc.getpwent)
    end

    # closes handle to /etc/passwd file
    def endpwent
      ::Etc.endpwent
    end

    #effectively equivalent to IO#rewind of /etc/passwd
    def setpwent
      ::Etc.setpwent
    end

    # Etc::getpwnam searches /etc/passwd file for an entry corresponding to
    # username.
    # returns an Etc::Passwd struct corresponding to the entry or raises
    # ArgumentError if none
    def getpwnam(username)
      override_field_values_to_utf8(::Etc.getpwnam(username))
    end

    # Etc::getgrnam searches /etc/group file for an entry corresponding to groupname.
    # returns an Etc::Group struct corresponding to the entry or raises
    # ArgumentError if none
    def getgrnam(groupname)
      override_field_values_to_utf8(::Etc.getgrnam(groupname))
    end

    # Etc::getgrid searches /etc/group file for an entry corresponding to id.
    # returns an Etc::Group struct corresponding to the entry or raises
    # ArgumentError if none
    def getgrgid(id)
      override_field_values_to_utf8(::Etc.getgrgid(id))
    end

    # Etc::getpwuid searches /etc/passwd file for an entry corresponding to id.
    # returns an Etc::Passwd struct corresponding to the entry or raises
    # ArgumentError if none
    def getpwuid(id)
      override_field_values_to_utf8(::Etc.getpwuid(id))
    end

    private

    # @api private
    # Defines Puppet::Etc::Passwd struct class. Contains all of the original
    # member fields of Etc::Passwd, and additional "canonical_" versions of
    # these fields as well. API compatible with Etc::Passwd. Because Struct.new
    # defines a new Class object, we memoize to avoid superfluous extra Class
    # instantiations.
    def puppet_etc_passwd_class
      @password_class ||= Struct.new(*Etc::Passwd.members, *Etc::Passwd.members.map { |member| "canonical_#{member}".to_sym })
    end

    # @api private
    # Defines Puppet::Etc::Group struct class. Contains all of the original
    # member fields of Etc::Group, and additional "canonical_" versions of these
    # fields as well. API compatible with Etc::Group. Because Struct.new
    # defines a new Class object, we memoize to avoid superfluous extra Class
    # instantiations.
    def puppet_etc_group_class
      @group_class ||= Struct.new(*Etc::Group.members, *Etc::Group.members.map { |member| "canonical_#{member}".to_sym })
    end

    # Utility method for overriding the String values of a struct returned by
    # the Etc module to UTF-8. Structs returned by the ruby Etc module contain
    # members with fields of type String, Integer, or Array of Strings, so we
    # handle these types. Otherwise ignore fields.
    #
    # @api private
    # @param [Etc::Passwd or Etc::Group struct]
    # @return [Puppet::Etc::Passwd or Puppet::Etc::Group struct] a new struct
    #   object with the original struct values overridden to UTF-8, if valid. For
    #   invalid values originating in UTF-8, invalid characters are replaced with
    #   '?'. For each member the struct also contains a corresponding
    #   :canonical_<member name> struct member.
    def override_field_values_to_utf8(struct)
      return nil if struct.nil?
      new_struct = struct.is_a?(Etc::Passwd) ? puppet_etc_passwd_class.new : puppet_etc_group_class.new
      struct.each_pair do |member, value|
        if value.is_a?(String)
          new_struct["canonical_#{member}".to_sym] = value.dup
          new_struct[member] = Puppet::Util::CharacterEncoding.scrub(Puppet::Util::CharacterEncoding.override_encoding_to_utf_8(value))
        elsif value.is_a?(Array)
          new_struct["canonical_#{member}".to_sym] = value.inject([]) { |acc, elem| acc << elem.dup }
          new_struct[member] = value.inject([]) { |acc, elem| acc << Puppet::Util::CharacterEncoding.scrub(Puppet::Util::CharacterEncoding.override_encoding_to_utf_8(elem)) }
        else
          new_struct["canonical_#{member}".to_sym] = value
          new_struct[member] = value
        end
      end
      new_struct
    end
  end
end



