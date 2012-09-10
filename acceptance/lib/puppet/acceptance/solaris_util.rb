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
    module SMFUtils
      def clean(agent, o={})
        o = {:service => 'tstapp'}.merge(o)
        on agent, "svcadm disable %s ||:" % o[:service]
        on agent, "svccfg delete %s ||:" % o[:service]
        on agent, "rm -rf /var/svc/manifest/application/%s.xml ||:" % o[:service]
        on agent, "rm -f /opt/bin/%s ||:" % o[:service]
      end
      def setup(agent, o={})
        setup_methodscript(agent, o)
      end

      def setup_methodscript(agent, o={})
        o = {:service => 'tstapp'}.merge(o)
        on agent, "mkdir -p /opt/bin"
        create_remote_file agent, '/lib/svc/method/%s' % o[:service], %[
case "$1" in
  start) nohup /opt/bin/%s & ;;
  stop) kill -9 $(cat /tmp/%s.pid) ||: ;;
  refresh) kill -9 $(cat /tmp/%s.pid) ; nohup /opt/bin/%s & ;;
  *) echo "Usage: $0 { start | stop | refresh }" ; exit 1 ;;
esac
exit $SMF_EXIT_OK
        ] % ([o[:service]] * 4)
        create_remote_file agent, ('/opt/bin/%s' % o[:service]), %[
echo $$ > /tmp/%s.pidfile
sleep 5
        ] % o[:service]
        on agent, "chmod 755 /lib/svc/method/%s" % o[:service]
        on agent, "chmod 755 /opt/bin/%s" % o[:service]
        on agent, "mkdir -p /var/svc/manifest/application"
        create_remote_file agent, ('/var/svc/manifest/application/%s.xml' % o[:service]),
%[<?xml version="1.0"?>
<!DOCTYPE service_bundle SYSTEM "/usr/share/lib/xml/dtd/service_bundle.dtd.1">
<service_bundle type='manifest' name='%s:default'>
  <service name='application/tstapp' type='service' version='1'>
  <create_default_instance enabled='false' />
  <single_instance />
  <method_context> <method_credential user='root' group='root' /> </method_context>
  <exec_method type='method' name='start' exec='/lib/svc/method/%s start' timeout_seconds="60" />
  <exec_method type='method' name='stop' exec='/lib/svc/method/%s stop' timeout_seconds="60" />
  <exec_method type='method' name='refresh' exec='/lib/svc/method/%s refresh' timeout_seconds="60" />
  <stability value='Unstable' />
  <template>
    <common_name> <loctext xml:lang='C'>Dummy</loctext> </common_name>
    <documentation>
      <manpage title='tstapp' section='1m' manpath='/usr/share/man' />
    </documentation>
  </template>
</service>
</service_bundle>
        ] % ([o[:service]] * 4)
        on agent, "svccfg -v validate /var/svc/manifest/application/%s.xml" % o[:service]
        on agent, "echo > /var/svc/log/application-%s:default.log" % o[:service]
        return ("/var/svc/manifest/application/%s.xml" % o[:service]), ("/lib/svc/method/%s" % o[:service])
      end
    end
    module ZFSUtils
      def clean(agent, o={})
        o = {:fs=>'tstfs', :pool=>'tstpool', :poolpath => '/ztstpool'}.merge(o)
        on agent, "zfs destroy -r %s/%s ||:" % [o[:pool], o[:fs]]
        on agent, "zpool destroy %s ||:" %  o[:pool]
        on agent, "rm -rf %s ||:" % o[:poolpath]
      end

      def setup(agent, o={})
        o = {:poolpath=>'/ztstpool', :pool => 'tstpool'}.merge(o)
        on agent, "mkdir -p %s/mnt" % o[:poolpath]
        on agent, "mkdir -p %s/mnt2" % o[:poolpath]
        on agent, "mkfile 64m %s/dsk" % o[:poolpath]
        on agent, "zpool create %s %s/dsk" % [ o[:pool],  o[:poolpath]]
      end
    end
    module ZPoolUtils
      def clean(agent, o={})
        o = {:pool=>'tstpool', :poolpath => '/ztstpool'}.merge(o)
        on agent, "zpool destroy %s ||:" % o[:pool]
        on agent, "rm -rf %s ||:" % o[:poolpath]
      end

      def setup(agent, o={})
        o = {:poolpath => '/ztstpool'}.merge(o)
        on agent, "mkdir -p %s/mnt||:" % o[:poolpath]
        on agent, "mkfile 100m %s/dsk1 %s/dsk2 %s/dsk3 %s/dsk5 ||:" % ([o[:poolpath]] * 4)
        on agent, "mkfile 50m %s/dsk4 ||:" % o[:poolpath]
      end
    end
  end
end
