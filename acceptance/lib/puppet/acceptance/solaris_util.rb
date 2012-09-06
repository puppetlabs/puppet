module Puppet
  module Acceptance
    module ZoneUtils
      def clean(agent)
        on agent,"zoneadm -z tstzone halt ||:"
        on agent,"zoneadm -z tstzone uninstall -F ||:"
        on agent,"zonecfg -z tstzone delete -F ||:"
        on agent,"rm -f /etc/zones/tstzone.xml ||:"
        on agent,"zfs destroy -r tstpool/tstfs ||:"
        on agent,"zpool destroy tstpool ||:"
        on agent,"rm -rf /tstzones ||:"
      end

      def setup(agent)
        on agent,"mkdir -p /tstzones/mnt"
        on agent,"chmod -R 700 /tstzones"
        on agent,"mkfile 1024m /tstzones/dsk"
        on agent,"zpool create tstpool /tstzones/dsk"
        on agent,"zfs create -o mountpoint=/tstzones/mnt tstpool/tstfs"
        on agent,"chmod 700 /tstzones/mnt"
      end
    end
    module CronUtils
      def clean(agent)
        on agent, "userdel monitor ||:"
        on agent, "groupdel monitor ||:"
        on agent, "mv /var/spool/cron/crontabs/root.orig /var/spool/cron/crontabs/root ||:"
      end

      def setup(agent)
        on agent, "cp /var/spool/cron/crontabs/root /var/spool/cron/crontabs/root.orig"
      end
    end
    module IPSUtils
      def clean(agent, o={})
        o = {:repo => '/var/tstrepo', :pkg => 'mypkg', :publisher => 'tstpub.lan'}.merge(o)
        on agent, "rm -rf %s||:" % o[:repo]
        on agent, "rm -rf /tst||:"
        on agent, "pkg uninstall %s||:" % o[:pkg]
        on agent, "pkg unset-publisher %s ||:" % o[:publisher]
      end
      def setup(agent, o={})
        o = {:repo => '/var/tstrepo', :publisher => 'tstpub.lan'}.merge(o)
        on agent, "mkdir -p %s" % o[:repo]
        on agent, "pkgrepo create %s" % o[:repo]
        on agent, "pkgrepo set -s %s publisher/prefix=%s" % [o[:repo], o[:publisher]]
        on agent, "pkgrepo -s %s refresh" % o[:repo]
      end
      def setup_fakeroot(agent, o={})
        o = {:root=>'/opt/fakeroot'}.merge(o)
        on agent, "rm -rf %s" % o[:root]
        on agent, "mkdir -p %s/tst/usr/bin" % o[:root]
        on agent, "mkdir -p %s/tst/etc" % o[:root]
        on agent, "echo dummy > %s/tst/usr/bin/x" % o[:root]
        on agent, "echo val > %s/tst/etc/y" % o[:root]
      end
      def send_pkg(agent, o={})
        o = {:repo=>'/var/tstrepo', :root=>'/opt/fakeroot', :publisher=>'tstpub.lan', :pkg=>'mypkg@0.0.1'}.merge(o)
        on agent, "(pkgsend generate %s; echo set name=pkg.fmri value=pkg://%s/%s)> /tmp/%s.p5m" % [o[:root], o[:publisher], o[:pkg], o[:pkg]]
        on agent, "pkgsend publish -d %s -s %s /tmp/%s.p5m" % [o[:root], o[:repo], o[:pkg]]
        on agent, "pkgrepo refresh -p %s -s %s" % [o[:publisher], o[:repo]]
        on agent, "pkg refresh"
      end
      def set_publisher(agent, o={})
        o = {:repo=>'/var/tstrepo', :publisher=>'tstpub.lan'}.merge(o)
        on agent, "pkg set-publisher -g %s %s" % [o[:repo], o[:publisher]]
        on agent, "pkg refresh"
      end
    end
  end
end
