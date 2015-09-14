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
    if current == :absent and should.empty?
      return true
    else
      if current.respond_to?(:sort) and should.respond_to?(:sort)
        return current.sort.uniq == should.sort.uniq
      else
        return current == should
      end
    end
  end

end
