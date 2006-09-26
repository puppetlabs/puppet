require 'facter'

module Puppet
    module SUIDManager
        platform = Facter["kernel"].value
        [:uid=, :gid=, :uid, :gid].each do |method|
            define_method(method) do |*args|
                # NOTE: 'method' is closed here.
                newmethod = method

                if platform == "Darwin"
                    if !@darwinwarned
                        Puppet.warning "Cannot change real UID on Darwin"
                        @darwinwarned = true
                    end
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

        def run_and_capture(command, new_uid=self.euid, new_gid=self.egid)
            output = nil

            asuser(new_uid, new_gid) do
                # capture both stdout and stderr unless we are on ruby < 1.8.4
                # NOTE: this would be much better facilitated with a specialized popen()
                #       (see the test suite for more details.)
                if (Facter['rubyversion'].value <=> "1.8.4") < 0
                   unless @@alreadywarned
                        Puppet.warning "Cannot capture STDERR when running as another user on Ruby < 1.8.4"
                        @@alreadywarned = true
                    end
                    output = %x{#{command}}
                else
                    output = %x{#{command} 2>&1}
                end
            end

            [output, $?.dup]
        end

        module_function :run_and_capture

        def system(command, new_uid=self.euid, new_gid=self.egid)
            status = nil
            asuser(new_uid, new_gid) do
                Kernel.system(command)
                status = $?.dup
            end
            status
        end
        
        module_function :system

        def asuser(new_euid=nil, new_egid=nil)
            old_egid = old_euid = nil
            if new_egid
                new_egid = Puppet::Util.uid(new_egid)
                old_egid = self.egid
                self.egid = new_egid
            end
            if new_euid
                new_euid = Puppet::Util.uid(new_euid)
                old_euid = self.euid
                self.euid = new_euid
            end

            return yield
        ensure
            self.egid = old_egid if old_egid
            self.euid = old_euid if old_euid
        end

        module_function :asuser
    end
end

# $Id$
