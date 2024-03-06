# frozen_string_literal: true

require_relative '../../../puppet/provider/nameservice/directoryservice'

Puppet::Type.type(:group).provide :directoryservice, :parent => Puppet::Provider::NameService::DirectoryService do
  desc "Group management using DirectoryService on OS X.

  "

  commands :dscl => "/usr/bin/dscl"
  confine 'os.name' => :darwin
  defaultfor 'os.name' => :darwin
  has_feature :manages_members

  def members_insync?(current, should)
    return false unless current

    if current == :absent
      should.empty?
    else
      current.sort.uniq == should.sort.uniq
    end
  end
end
