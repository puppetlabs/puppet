module Puppet
    newtype(:zpool) do
        @doc = "Manage zpools. Create and delete zpools. The provider WILL NOT SYNC, only report differences.

                Supports vdevs with mirrors, raidz, logs and spares."

        ensurable

        newproperty(:disk, :array_matching => :all) do
            desc "The disk(s) for this pool. Can be an array or space separated string"
        end

        newproperty(:mirror, :array_matching => :all) do
            desc "List of all the devices to mirror for this pool. Each mirror should be a space separated string.
                  mirror => [\"disk1 disk2\", \"disk3 disk4\"]"

            validate do |value|
                if value.include?(",")
                    raise ArgumentError, "mirror names must be provided as string separated, not a comma-separated list"
                end
            end
        end

        newproperty(:raidz, :array_matching => :all) do
            desc "List of all the devices to raid for this pool. Should be an array of space separated strings.
                  raidz => [\"disk1 disk2\", \"disk3 disk4\"]"

            validate do |value|
                if value.include?(",")
                    raise ArgumentError, "raid names must be provided as string separated, not a comma-separated list"
                end
            end
        end

        newproperty(:spare, :array_matching => :all) do
            desc "Spare disk(s) for this pool."
        end

        newproperty(:log, :array_matching => :all) do
            desc "Log disks for this pool. (doesn't support mirroring yet)"
        end

        newparam(:pool) do
            desc "The name for this pool."
            isnamevar
       end

        newparam(:raid_parity) do
            desc "Determines parity when using raidz property."
        end

        validate do
            has_should = [:disk, :mirror, :raidz].select { |prop| self.should(prop) }
            if has_should.length > 1
                self.fail "You cannot specify %s on this type (only one)" % has_should.join(" and ")
            end
        end
    end
end

