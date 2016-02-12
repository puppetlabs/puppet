# Windows Access Control List
#
# Represents a list of access control entries (ACEs).
#
# @see https://msdn.microsoft.com/en-us/library/windows/desktop/aa374872(v=vs.85).aspx
# @api private
class Puppet::Util::Windows::AccessControlList
  include Enumerable

  ACCESS_ALLOWED_ACE_TYPE                 = 0x0
  ACCESS_DENIED_ACE_TYPE                  = 0x1

  # Construct an ACL.
  #
  # @param acl [Enumerable] A list of aces to copy from.
  def initialize(acl = nil)
    if acl
      @aces = acl.map(&:dup)
    else
      @aces = []
    end
  end

  # Enumerate each ACE in the list.
  #
  # @yieldparam ace [Hash] the ace
  def each
    @aces.each {|ace| yield ace}
  end

  # Allow the +sid+ to access a resource with the specified access +mask+.
  #
  # @param sid [String] The SID that the ACE is granting access to
  # @param mask [int] The access mask granted to the SID
  # @param flags [int] The flags assigned to the ACE, e.g. +INHERIT_ONLY_ACE+
  def allow(sid, mask, flags = 0)
    @aces << Puppet::Util::Windows::AccessControlEntry.new(sid, mask, flags, ACCESS_ALLOWED_ACE_TYPE)
  end

  # Deny the +sid+ access to a resource with the specified access +mask+.
  #
  # @param sid [String] The SID that the ACE is denying access to
  # @param mask [int] The access mask denied to the SID
  # @param flags [int] The flags assigned to the ACE, e.g. +INHERIT_ONLY_ACE+
  def deny(sid, mask, flags = 0)
    @aces << Puppet::Util::Windows::AccessControlEntry.new(sid, mask, flags, ACCESS_DENIED_ACE_TYPE)
  end

  # Reassign all ACEs currently assigned to +old_sid+ to +new_sid+ instead.
  # If an ACE is inherited or is not assigned to +old_sid+, then it will
  # be copied as-is to the new ACL, preserving its order within the ACL.
  #
  # @param old_sid [String] The old SID, e.g. 'S-1-5-18'
  # @param new_sid [String] The new SID
  # @return [AccessControlList] The copied ACL.
  def reassign!(old_sid, new_sid)
    new_aces = []
    prepend_needed = false
    aces_to_prepend = []

    @aces.each do |ace|
      new_ace = ace.dup

      if ace.sid == old_sid
        if ace.inherited?
          # create an explicit ACE granting or denying the
          # new_sid the rights that the inherited ACE
          # granted or denied the old_sid. We mask off all
          # flags except those affecting inheritance of the
          # ACE we're creating.
          inherit_mask = Puppet::Util::Windows::AccessControlEntry::CONTAINER_INHERIT_ACE |
            Puppet::Util::Windows::AccessControlEntry::OBJECT_INHERIT_ACE |
            Puppet::Util::Windows::AccessControlEntry::INHERIT_ONLY_ACE
          explicit_ace = Puppet::Util::Windows::AccessControlEntry.new(new_sid, ace.mask, ace.flags & inherit_mask, ace.type)
          aces_to_prepend << explicit_ace
        else
          new_ace.sid = new_sid

          prepend_needed = old_sid == Puppet::Util::Windows::SID::LocalSystem
        end
      end
      new_aces << new_ace
    end

    @aces = []

    if prepend_needed
      mask = Puppet::Util::Windows::File::STANDARD_RIGHTS_ALL | Puppet::Util::Windows::File::SPECIFIC_RIGHTS_ALL
      ace = Puppet::Util::Windows::AccessControlEntry.new(
              Puppet::Util::Windows::SID::LocalSystem,
              mask)
      @aces << ace
    end

    @aces.concat(aces_to_prepend)
    @aces.concat(new_aces)
  end

  def inspect
    str = ""
    @aces.each do |ace|
      str << "  #{ace.inspect}\n"
    end
    str
  end

  def ==(other)
    self.class == other.class &&
      self.to_a == other.to_a
  end

  alias eql? ==
end
