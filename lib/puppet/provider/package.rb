#  Created by Luke A. Kanies on 2007-06-05.
#  Copyright (c) 2007. All rights reserved.

class Puppet::Provider::Package < Puppet::Provider
    # Prefetch our package list, yo.
    def self.prefetch(packages)
        instances.each do |prov|
            if pkg = packages[prov.name]
                pkg.provider = prov
            end
        end
    end

    # Clear out the cached values.
    def flush
        @property_hash.clear
    end

    # Look up the current status.
    def properties
        if @property_hash.empty?
            @property_hash = query || {:ensure => :absent}
            if @property_hash.empty?
                @property_hash[:ensure] = :absent
            end
        end
        @property_hash.dup
    end
end
