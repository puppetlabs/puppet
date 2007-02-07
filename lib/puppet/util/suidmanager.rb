require 'facter'
require 'puppet/util/warnings'

module Puppet::Util::SUIDManager
    include Puppet::Util::Warnings

    platform = Facter["kernel"].value
    [:uid=, :gid=, :uid, :gid].each do |method|
        define_method(method) do |*args|
            # NOTE: 'method' is closed here.
            newmethod = method

            if platform == "Darwin" and (method == :uid= or method == :gid=)
                Puppet::Util::Warnings.warnonce "Cannot change real UID on Darwin"
                newmethod = ("e" + method.to_s).intern
            end

            return Process.send(newmethod, *args)
        end
        module_function method
    end

    [:euid=, :euid, :egid=, :egid].each do |method|
        define_method(method) do |*args|
            Process.send(method, *args)
        end
        module_function method
    end

    def asuser(new_euid=nil, new_egid=nil)
        # Unless we're root, don't do a damn thing.
        unless Process.uid == 0
            return yield
        end
        old_egid = old_euid = nil
        if new_egid
            old_egid = self.egid
            self.egid = convert_xid(:gid, new_egid)
        end
        if new_euid
            old_euid = self.euid
            self.euid = convert_xid(:uid, new_euid)
        end

        return yield
    ensure
        self.euid = old_euid if old_euid
        self.egid = old_egid if old_egid
    end
    
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

    module_function :asuser, :convert_xid

    def run_and_capture(command, new_uid=nil, new_gid=nil)
        output = nil
        
        output = Puppet::Util.execute(command, false, new_uid, new_gid)

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

# $Id$
