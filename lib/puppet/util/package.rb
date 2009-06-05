require 'puppet'

module Puppet::Util::Package
    def versioncmp(version_a, version_b)
        vre = /[-.]|\d+|[^-.\d]+/
        ax = version_a.scan(vre)
        bx = version_b.scan(vre)

        while (ax.length>0 && bx.length>0) do
            a = ax.shift
            b = bx.shift

            if( a == b )                 then next
            elsif (a == '-' && b == '-') then next
            elsif (a == '-')             then return -1
            elsif (b == '-')             then return 1
            elsif (a == '.' && b == '.') then next
            elsif (a == '.' )            then return -1
            elsif (b == '.' )            then return 1
            elsif (a =~ /^\d+$/ && b =~ /^\d+$/) then
                if( a =~ /^0/ or b =~ /^0/ ) then
                    return a.to_s.upcase <=> b.to_s.upcase
                end
                return a.to_i <=> b.to_i
            else
                return a.upcase <=> b.upcase
            end
        end
        return version_a <=> version_b;
    end

    module_function :versioncmp
end
