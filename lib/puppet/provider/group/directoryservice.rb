require 'puppet/provider/nameservice/directoryservice'

Puppet::Type.type(:group).provide :directoryservice, :parent => Puppet::Provider::NameService::DirectoryService do
  desc "Group management using DirectoryService on OS X.

  "

  commands :dscl => "/usr/bin/dscl"
  confine :operatingsystem => :darwin
  defaultfor :operatingsystem => :darwin
  has_feature :manages_members

  def members_insync?(current, should)
    return false unless current
    if current == :absent
      return should.empty?
    else
      return current.sort.uniq == should.sort.uniq
    end
  end

end
