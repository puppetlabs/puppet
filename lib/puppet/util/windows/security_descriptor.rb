# Windows Security Descriptor
#
# Represents a security descriptor that can be applied to any Windows securable
# object, e.g. file, registry key, service, etc. It consists of an owner, group,
# flags, DACL, and SACL. The SACL is not currently supported, though it has the
# same layout as a DACL.
#
# @see https://msdn.microsoft.com/en-us/library/windows/desktop/aa379563(v=vs.85).aspx
# @api private
class Puppet::Util::Windows::SecurityDescriptor
  require 'puppet/util/windows/security'
  include Puppet::Util::Windows::SID

  attr_reader :owner, :group, :dacl
  attr_accessor :protect

  # Construct a security descriptor
  #
  # @param owner [String] The SID of the owner, e.g. 'S-1-5-18'
  # @param group [String] The SID of the group
  # @param dacl [AccessControlList] The ACL specifying the rights granted to
  # each user for accessing the object that the security descriptor refers to.
  # @param protect [Boolean] If true, then inheritable access control
  # entries will be blocked, and not applied to the object.
  def initialize(owner, group, dacl, protect = false)
    @owner = owner
    @group = group
    @dacl = dacl
    @protect = protect
  end

  # Set the owner. Non-inherited access control entries assigned to the
  # current owner will be assigned to the new owner.
  #
  # @param new_owner [String] The SID of the new owner, e.g. 'S-1-5-18'
  def owner=(new_owner)
    if @owner != new_owner
      @dacl.reassign!(@owner, new_owner)
      @owner = new_owner
    end
  end

  # Set the group. Non-inherited access control entries assigned to the
  # current group will be assigned to the new group.
  #
  # @param new_group [String] The SID of the new group, e.g. 'S-1-0-0'
  def group=(new_group)
    if @group != new_group
      @dacl.reassign!(@group, new_group)
      @group = new_group
    end
  end

  def inspect
    str = sid_to_name(owner)
    str << "\n"
    str << sid_to_name(group)
    str << "\n"
    str << @dacl.inspect
    str
  end
end
