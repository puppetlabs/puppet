require 'puppet/util/warnings'
require 'forwardable'

module Puppet::Util::SUIDManager
    include Puppet::Util::Warnings
    extend Forwardable

    # Note groups= is handled specially due to a bug in OS X 10.6
    to_delegate_to_process = [ :euid=, :euid, :egid=, :egid,
                               :uid=, :uid, :gid=, :gid, :groups ]

    to_delegate_to_process.each do |method|
        def_delegator Process, method
        module_function method
    end

    def osx_maj_ver
        return @osx_maj_ver unless @osx_maj_ver.nil?
        require 'facter'
        # 'kernel' is available without explicitly loading all facts
        if Facter.value('kernel') != 'Darwin'
          @osx_maj_ver = false
          return @osx_maj_ver
        end
        # But 'macosx_productversion_major' requires it.
        Facter.loadfacts
        @osx_maj_ver = Facter.value('macosx_productversion_major')
        return @osx_maj_ver
    end
    module_function :osx_maj_ver
    
    def groups=(grouplist)
        if osx_maj_ver == '10.6'
            return true
        else
            return Process.groups = grouplist
        end
    end
    module_function :groups=

    if Facter['kernel'].value == 'Darwin'
        # Cannot change real UID on Darwin so we set euid
        alias :uid :euid
        alias :gid :egid
    end

    # Runs block setting uid and gid if provided then restoring original ids
    def asuser(new_uid=nil, new_gid=nil)
        return yield unless Process.uid == 0
        # We set both because some programs like to drop privs, i.e. bash.
        old_uid, old_gid = self.uid, self.gid
        old_euid, old_egid = self.euid, self.egid
        old_groups = self.groups
        begin
            self.egid = convert_xid :gid, new_gid if new_gid
            self.initgroups(convert_xid(:uid, new_uid)) if new_uid
            self.euid = convert_xid :uid, new_uid if new_uid

            yield
        ensure
            self.euid, self.egid = old_euid, old_egid
            self.groups = old_groups
        end
    end
    module_function :asuser

    # Make sure the passed argument is a number.
    def convert_xid(type, id)
        map = {:gid => :group, :uid => :user}
        raise ArgumentError, "Invalid id type %s" % type unless map.include?(type)
        ret = Puppet::Util.send(type, id)
        if ret == nil
          raise Puppet::Error, "Invalid %s: %s" % [map[type], id]
        end
        return ret
    end
    module_function :convert_xid

    # Initialize supplementary groups
    def initgroups(user)
        require 'etc'
        Process.initgroups(Etc.getpwuid(user).name, Process.gid)
    end

    module_function :initgroups

    def run_and_capture(command, new_uid=nil, new_gid=nil)
        output = Puppet::Util.execute(command, :failonfail => false, :uid => new_uid, :gid => new_gid)
        [output, $?.dup]
    end
    module_function :run_and_capture

    def system(command, new_uid=nil, new_gid=nil)
        status = nil
        asuser(new_uid, new_gid) do
            Kernel.system(command)
            status = $?.dup
        end
        status
    end
    module_function :system
end

