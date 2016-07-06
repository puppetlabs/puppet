# Windows Access Control Entry
#
# Represents an access control entry, which grants or denies a subject,
# identified by a SID, rights to a securable object.
#
# @see https://msdn.microsoft.com/en-us/library/windows/desktop/aa374868(v=vs.85).aspx
# @api private
class Puppet::Util::Windows::AccessControlEntry
  require 'puppet/util/windows/security'
  include Puppet::Util::Windows::SID

  attr_accessor :sid
  attr_reader :mask, :flags, :type

  OBJECT_INHERIT_ACE                      = 0x1
  CONTAINER_INHERIT_ACE                   = 0x2
  NO_PROPAGATE_INHERIT_ACE                = 0x4
  INHERIT_ONLY_ACE                        = 0x8
  INHERITED_ACE                           = 0x10

  ACCESS_ALLOWED_ACE_TYPE                 = 0x0
  ACCESS_DENIED_ACE_TYPE                  = 0x1

  def initialize(sid, mask, flags = 0, type = ACCESS_ALLOWED_ACE_TYPE)
    @sid = sid
    @mask = mask
    @flags = flags
    @type = type
  end

  # Returns true if this ACE is inherited from a parent. If false,
  # then the ACE is set directly on the object to which it refers.
  #
  # @return [Boolean] true if the ACE is inherited
  def inherited?
    (@flags & INHERITED_ACE) == INHERITED_ACE
  end

  # Returns true if this ACE only applies to children of the object.
  # If false, it applies to the object.
  #
  # @return [Boolean] true if the ACE only applies to children and
  # not the object itself.
  def inherit_only?
    (@flags & INHERIT_ONLY_ACE) == INHERIT_ONLY_ACE
  end

  # Returns true if this ACE applies to child directories.
  #
  # @return [Boolean] true if the ACE applies to child directories
  def container_inherit?
    (@flags & CONTAINER_INHERIT_ACE) == CONTAINER_INHERIT_ACE
  end

  # Returns true if this ACE applies to child files.
  #
  # @return [Boolean] true if the ACE applies to child files.
  def object_inherit?
    (@flags & OBJECT_INHERIT_ACE) == OBJECT_INHERIT_ACE
  end

  def inspect
    inheritance = ""
    inheritance << '(I)' if inherited?
    inheritance << '(OI)' if object_inherit?
    inheritance << '(CI)' if container_inherit?
    inheritance << '(IO)' if inherit_only?

    left = "#{sid_to_name(sid)}:#{inheritance}"
    left = left.ljust(45)
    "#{left} 0x#{mask.to_s(16)}"
  end

  # Returns true if this ACE is equal to +other+
  def ==(other)
    self.class == other.class &&
      sid == other.sid &&
      mask == other.mask &&
      flags == other.flags &&
      type == other.type
  end

  alias eql? ==
end
