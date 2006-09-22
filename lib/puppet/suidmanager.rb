require 'facter'
require 'puppet'

module Puppet
    module SUIDManager
        platform = Facter["kernel"].value
        [:uid=, :uid, :gid=, :gid].each do |method|
            define_method(method) do |*args|
                if platform == "Darwin" and (Facter['rubyversion'] <=> "1.8.5") < 0
                    Puppet.warning "Cannot change real UID on Darwin on Ruby versions earlier than 1.8.5"
                    method = ("e" + method.to_s).intern unless method.to_s[0] == 'e'
                end

                return Process.send(method, *args)
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
            asuser(new_uid, new_gid) do
                Kernel.system(command)
            end
        end
        
        module_function :system

        def asuser(new_euid, new_egid)
            new_euid = Puppet::Util.uid(new_euid)
            new_egid = Puppet::Util.uid(new_egid)

            old_euid, old_egid = [ self.euid, self.egid ]
            self.egid = new_egid ? new_egid : old_egid
            self.euid = new_euid ? new_euid : old_euid
            output = yield
            self.egid = old_egid
            self.euid = old_euid

            output
        end

        module_function :asuser
    end
end

