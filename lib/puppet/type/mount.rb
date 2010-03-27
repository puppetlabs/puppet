module Puppet
    # We want the mount to refresh when it changes.
    newtype(:mount, :self_refresh => true) do
        @doc = "Manages mounted filesystems, including putting mount
            information into the mount table. The actual behavior depends
            on the value of the 'ensure' parameter.

            Note that if a ``mount`` receives an event from another resource,
            it will try to remount the filesystems if ``ensure`` is set to ``mounted``."

        feature :refreshable, "The provider can remount the filesystem.",
            :methods => [:remount]

        # Use the normal parent class, because we actually want to
        # call code when sync() is called.
        newproperty(:ensure) do
            desc "Control what to do with this mount. Set this attribute to
                ``present`` to make sure the filesystem is in the filesystem table
                but not mounted (if the filesystem is currently mounted, it will be
                unmounted).  Set it to ``absent`` to unmount (if necessary) and remove
                the filesystem from the fstab.  Set to ``mounted`` to add it to the
                fstab and mount it."

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
                provider.create if current_value.nil? or current_value == :absent

                syncothers()

                # The fs can be already mounted if it was absent but mounted
                provider.mount unless provider.mounted?
            end

            def retrieve
                # We need to special case :mounted; if we're absent, we still
                # want
                curval = super()
                if curval == :absent
                    return curval
                elsif provider.mounted?
                    return :mounted
                else
                    return curval
                end
            end

            def syncothers
                # We have to flush any changes to disk.
                currentvalues = @resource.retrieve

                # Determine if there are any out-of-sync properties.
                oos = @resource.send(:properties).find_all do |prop|
                    unless currentvalues.include?(prop)
                        raise Puppet::DevError, "Parent has property %s but it doesn't appear in the current values", [prop.name]
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
            desc "The device to fsck.  This is property is only valid
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

            defaultto {
                if @resource.managed?
                    0
                end
            }
        end

        newproperty(:atboot) do
            desc "Whether to mount the mount at boot.  Not all platforms
                support this."
        end

        newproperty(:dump) do
            desc "Whether to dump the mount.  Not all platform support this. 
                Valid values are ``1`` or ``0``. or ``2`` on FreeBSD, Default is ``0``." 
            
            if Facter["operatingsystem"].value == "FreeBSD" 
                newvalue(%r{(0|1|2)})
            else
                newvalue(%r{(0|1)})
            end

            newvalue(%r{(0|1)})

            defaultto {
                if @resource.managed?
                    0
                end
            }
        end

        newproperty(:target) do
            desc "The file in which to store the mount table.  Only used by
                those providers that write to disk."

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
                when "FreeBSD", "Darwin"
                    false
                else
                    true
                end
            end
        end

        def refresh
            # Only remount if we're supposed to be mounted.
            provider.remount if self.should(:fstype) != "swap" and provider.mounted?
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

