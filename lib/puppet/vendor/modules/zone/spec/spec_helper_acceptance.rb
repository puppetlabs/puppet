module Puppet
  module Acceptance
    module ZoneUtils
      def clean(agent)
        lst = on(agent, "zoneadm list -cip").stdout.lines.each do |l|
          case l
          when /tstzone:running/
            on agent,"zoneadm -z tstzone halt"
            on agent,"zoneadm -z tstzone uninstall -F"
            on agent,"zonecfg -z tstzone delete -F"
            on agent,"rm -f /etc/zones/tstzone.xml"
          when /tstzone:configured/
            on agent,"zonecfg -z tstzone delete -F"
            on agent,"rm -f /etc/zones/tstzone.xml"
          when /tstzone:*/
            on agent,"zonecfg -z tstzone delete -F"
            on agent,"rm -f /etc/zones/tstzone.xml"
          end
        end
        lst = on(agent, "zfs list").stdout.lines.each do |l|
          case l
          when /rpool.tstzones/
            on agent,"zfs destroy -f -r rpool/tstzones"
          end
        end
        on agent, "rm -rf /tstzones"
      end

      def setup(agent, o={})
        o = {:size => '64m'}.merge(o)
      end
    end
  end
end
