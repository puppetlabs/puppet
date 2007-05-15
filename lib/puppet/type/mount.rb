module Puppet
    # We want the mount to refresh when it changes.
    newtype(:mount, :self_refresh => true) do
        @doc = "Manages mounted filesystems, including putting mount
            information into the mount table. The actual behavior depends 
            on the value of the 'ensure' parameter.
	    
            Note that if a ``mount`` receives an event from another resource,
            it will try to remount the filesystems if ``ensure => mounted`` is
            set."
        
        # Use the normal parent class, because we actually want to
        # call code when sync() is called.
        newproperty(:ensure) do
            desc "Control what to do with this mount. If the value is 
                  ``present``, the mount is entered into the mount table, 
                  but not mounted, if it is ``absent``, the entry is removed 
                  from the mount table and the filesystem is unmounted if 
                  currently mounted, if it is ``mounted``, the filesystem 
                  is entered into the mount table and mounted."

            newvalue(:present) do
                if provider.mounted?
                    syncothers()
                    provider.unmount
                    return :mount_unmounted
                else
                    provider.create
                    return :mount_created
                end
            end
            aliasvalue :unmounted, :present

            newvalue(:absent, :event => :mount_deleted) do
                if provider.mounted?
                    provider.unmount
                end

                provider.destroy
            end

            newvalue(:mounted, :event => :mount_mounted) do
                # Create the mount point if it does not already exist.
                current_value = self.retrieve
                if current_value.nil?  or current_value == :absent 
                    provider.create
                end

                syncothers()
                provider.mount
            end

            def retrieve
                return provider.mounted? ? :mounted : super()
            end

            def syncothers
                # We have to flush any changes to disk.
                currentvalues = @resource.retrieve
                oos = @resource.send(:properties).find_all do |prop|
                    unless currentvalues.include?(prop)
                        raise Puppet::DevError, 
                          "Parent has property %s but it doesn't appear in the current vallues",
                          [prop.name]
                    end
                    if prop.name == :ensure
                        false
                    else
                        ! prop.insync?(currentvalues[prop])
                    end
                end.each { |prop| prop.sync }.length
                if oos > 0
                    @resource.flush
                end
            end
        end

        newproperty(:device) do
            desc "The device providing the mount.  This can be whatever
                device is supporting by the mount, including network
                devices or devices specified by UUID rather than device
                path, depending on the operating system."
        end

        # Solaris specifies two devices, not just one.
        newproperty(:blockdevice) do
            desc "The the device to fsck.  This is property is only valid
                on Solaris, and in most cases will default to the correct
                value."

            # Default to the device but with "dsk" replaced with "rdsk".
            defaultto do
                if Facter["operatingsystem"].value == "Solaris"
                    device = @resource.value(:device)
                    if device =~ %r{/dsk/}
                        device.sub(%r{/dsk/}, "/rdsk/")
                    else
                        nil
                    end
                else
                    nil
                end
            end
        end

        newproperty(:fstype) do
            desc "The mount type.  Valid values depend on the
                operating system."
        end

        newproperty(:options) do
            desc "Mount options for the mounts, as they would
                appear in the fstab."
        end

        newproperty(:pass) do
            desc "The pass in which the mount is checked."
        end

        newproperty(:atboot) do
            desc "Whether to mount the mount at boot.  Not all platforms
                support this."
        end

        newproperty(:dump) do
            desc "Whether to dump the mount.  Not all platforms
                support this."
        end

        newproperty(:target) do
            desc "The file in which to store the mount table.  Only used by
                those providers that write to disk (i.e., not NetInfo)."

            defaultto { if @resource.class.defaultprovider.ancestors.include?(Puppet::Provider::ParsedFile)
                    @resource.class.defaultprovider.default_target
                else
                    nil
                end
            }
        end

        newparam(:name) do
            desc "The mount path for the mount."

            isnamevar
        end

        newparam(:path) do
            desc "The deprecated name for the mount point.  Please use ``name`` now."

            def value=(value)
                warning "'path' is deprecated for mounts.  Please use 'name'."
                @resource[:name] = value
                super
            end
        end
        
        newparam(:remounts) do
            desc "Whether the mount can be remounted  ``mount -o remount``.  If
                this is false, then the filesystem will be unmounted and remounted
                manually, which is prone to failure."
            
            newvalues(:true, :false)
            defaultto do
                case Facter.value(:operatingsystem)
                when "FreeBSD": false
                else
                    true
                end
            end
        end

        def refresh
            # Only remount if we're supposed to be mounted.
            if ens = @parameters[:ensure] and ens.should == :mounted
                provider.remount
            end
        end

        def value(name)
            name = symbolize(name)
            ret = nil
            if property = @parameters[name]
                return property.value
            end
        end
    end
end

# $Id$
