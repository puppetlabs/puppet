# The majority of the system configuration parameters are set in this file.
module Puppet
    # If we're running the standalone puppet process as a non-root user,
    # use basedirs that are in the user's home directory.
    conf = nil
    var = nil
    name = $0.gsub(/.+#{File::SEPARATOR}/,'').sub(/\.rb$/, '')
    if name != "puppetmasterd" and Puppet::Util::SUIDManager.uid != 0
        conf = File.expand_path("~/.puppet")
        var = File.expand_path("~/.puppet/var")
    else
        # Else, use system-wide directories.
        conf = "/etc/puppet"
        var = "/var/puppet"
    end

    self.setdefaults(:puppet,
        :confdir => [conf, "The main Puppet configuration directory."],
        :vardir => [var, "Where Puppet stores dynamic and growing data."],
        :name => [name, "The name of the service, if we are running as one.  The
            default is essentially $0 without the path or ``.rb``."]
    )

    if name == "puppetmasterd"
        logopts = {:default => "$vardir/log",
            :mode => 0750,
            :owner => "$user",
            :group => "$group",
            :desc => "The Puppet log directory."
        }
    else
        logopts = ["$vardir/log", "The Puppet log directory."]
    end
    setdefaults(:puppet, :logdir => logopts)
    
    # This name hackery is necessary so that the rundir is set reasonably during
    # unit tests.
    if Process.uid == 0 and %w{puppetd puppetmasterd}.include?(self.name)
        rundir = "/var/run/puppet"
    else
        rundir = "$vardir/run"
    end

    self.setdefaults(:puppet,
        :trace => [false, "Whether to print stack traces on some errors"],
        :autoflush => [false, "Whether log files should always flush to disk."],
        :syslogfacility => ["daemon", "What syslog facility to use when logging to
            syslog.  Syslog has a fixed list of valid facilities, and you must
            choose one of those; you cannot just make one up."],
        :statedir => { :default => "$vardir/state",
            :mode => 01777,
            :desc => "The directory where Puppet state is stored.  Generally,
                this directory can be removed without causing harm (although it
                might result in spurious service restarts)."
        },
        :statefile => { :default => "$statedir/state.yaml",
            :mode => 0660,
            :desc => "Where puppetd and puppetmasterd store state associated
                with the running configuration.  In the case of puppetmasterd,
                this file reflects the state discovered through interacting
                with clients."
            },
        :ssldir => {
            :default => "$confdir/ssl",
            :mode => 0771,
            :owner => "root",
            :desc => "Where SSL certificates are kept."
        },
        :rundir => { :default => rundir,
            :mode => 01777,
            :desc => "Where Puppet PID files are kept."
        },
        :genconfig => [false,
            "Whether to just print a configuration to stdout and exit.  Only makes
            sense when used interactively.  Takes into account arguments specified
            on the CLI."],
        :genmanifest => [false,
            "Whether to just print a manifest to stdout and exit.  Only makes
            sense when used interactively.  Takes into account arguments specified
            on the CLI."],
        :configprint => ["",
            "Print the value of a specific configuration parameter.  If a
            parameter is provided for this, then the value is printed and puppet
            exits.  Comma-separate multiple values.  For a list of all values,
            specify 'all'.  This feature is only available in Puppet versions
            higher than 0.18.4."],
        :color => ["ansi", "Whether to use colors when logging to the console.
            Valid values are ``ansi`` (equivalent to ``true``), ``html`` (mostly
            used during testing with TextMate), and ``false``, which produces
            no color."],
        :mkusers => [false,
            "Whether to create the necessary user and group that puppetd will
            run as."],
        :path => {:default => "none",
            :desc => "The shell search path.  Defaults to whatever is inherited
                from the parent process.",
            :hook => proc do |value|
                ENV["PATH"] = value unless value == "none"
            end
        },
        :libdir => {:default => "$vardir/lib",
            :desc => "An extra search path for Puppet.  This is only useful
                for those files that Puppet will load on demand, and is only
                guaranteed to work for those cases.  In fact, the autoload
                mechanism is responsible for making sure this directory
                is in Ruby's search path",
            :hook => proc do |value|
                if defined? @oldlibdir and $:.include?(@oldlibdir)
                    $:.delete(@oldlibdir)
                end
                @oldlibdir = value
                $: << value
            end
        },
        :ignoreimport => [false, "A parameter that can be used in commit
            hooks, since it enables you to parse-check a single file rather
            than requiring that all files exist."],
        :authconfig => [ "$confdir/namespaceauth.conf",
            "The configuration file that defines the rights to the different
            namespaces and methods.  This can be used as a coarse-grained
            authorization system for both ``puppetd`` and ``puppetmasterd``."
        ]
    )

    # Define the config default.
    self.setdefaults(self.name,
        :config => ["$confdir/#{Puppet[:name]}.conf",
            "The configuration file for #{Puppet[:name]}."],
        :pidfile => ["", "The pid file"],
        :bindaddress => ["", "The address to bind to.  Mongrel servers
            default to 127.0.0.1 and WEBrick defaults to 0.0.0.0."],
        :servertype => ["webrick", "The type of server to use.  Currently supported
            options are webrick and mongrel.  If you use mongrel, you will need
            a proxy in front of the process or processes, since Mongrel cannot
            speak SSL."]
    )

    self.setdefaults("puppetmasterd",
        :user => ["puppet", "The user puppetmasterd should run as."],
        :group => ["puppet", "The group puppetmasterd should run as."],
        :manifestdir => ["$confdir/manifests",
            "Where puppetmasterd looks for its manifests."],
        :manifest => ["$manifestdir/site.pp",
            "The entry-point manifest for puppetmasterd."],
        :masterlog => { :default => "$logdir/puppetmaster.log",
            :owner => "$user",
            :group => "$group",
            :mode => 0660,
            :desc => "Where puppetmasterd logs.  This is generally not used,
                since syslog is the default log destination."
        },
        :masterhttplog => { :default => "$logdir/masterhttp.log",
            :owner => "$user",
            :group => "$group",
            :mode => 0660,
            :create => true,
            :desc => "Where the puppetmasterd web server logs."
        },
        :masterport => [8140, "Which port puppetmasterd listens on."],
        :parseonly => [false, "Just check the syntax of the manifests."],
        :node_name => ["cert", "How the puppetmaster determines the client's identity 
           and sets the 'hostname' fact for use in the manifest, in particular 
           for determining which 'node' statement applies to the client. 
           Possible values are 'cert' (use the subject's CN in the client's 
           certificate) and 'facter' (use the hostname that the client 
           reported in its facts)"],
        :bucketdir => {
            :default => "$vardir/bucket",
            :mode => 0750,
            :owner => "$user",
            :group => "$group",
            :desc => "Where FileBucket files are stored."
        },
        :ca => [true, "Wether the master should function as a certificate authority."],
        :modulepath => [ "$confdir/modules:/usr/share/puppet/modules",
           "The search path for modules as a colon-separated list of
            directories." ]
    )

    self.setdefaults("puppetd",
        :localconfig => { :default => "$statedir/localconfig",
            :owner => "root",
            :mode => 0660,
            :desc => "Where puppetd caches the local configuration.  An
                extension indicating the cache format is added automatically."},
        :classfile => { :default => "$confdir/classes.txt",
            :owner => "root",
            :mode => 0644,
            :desc => "The file in which puppetd stores a list of the classes
                associated with the retrieved configuratiion.  Can be loaded in
                the separate ``puppet`` executable using the ``--loadclasses``
                option."},
        :puppetdlog => { :default => "$logdir/puppetd.log",
            :owner => "root",
            :mode => 0640,
            :desc => "The log file for puppetd.  This is generally not used."
        },
        :httplog => { :default => "$logdir/http.log",
            :owner => "root",
            :mode => 0640,
            :desc => "Where the puppetd web server logs."
        },
        :server => ["puppet",
            "The server to which server puppetd should connect"],
        :ignoreschedules => [false,
            "Boolean; whether puppetd should ignore schedules.  This is useful
            for initial puppetd runs."],
        :puppetport => [8139, "Which port puppetd listens on."],
        :noop => [false, "Whether puppetd should be run in noop mode."],
        :runinterval => [1800, # 30 minutes
            "How often puppetd applies the client configuration; in seconds."],
        :listen => [false, "Whether puppetd should listen for
            connections.  If this is true, then by default only the
            ``runner`` server is started, which allows remote authorized
            and authenticated nodes to connect and trigger ``puppetd``
            runs."],
        :ca_server => ["$server", "The server to use for certificate
            authority requests.  It's a separate server because it cannot
            and does not need to horizontally scale."],
        :ca_port => ["$masterport", "The port to use for the certificate authority."]
    )
        
    self.setdefaults("filebucket",
        :clientbucketdir => {
            :default => "$vardir/clientbucket",
            :mode => 0750,
            :desc => "Where FileBucket files are stored locally."
        }
    )
    self.setdefaults("fileserver",
        :fileserverconfig => ["$confdir/fileserver.conf",
            "Where the fileserver configuration is stored."]
    )
    self.setdefaults(:reporting,
        :reports => ["store",
            "The list of reports to generate.  All reports are looked for
            in puppet/reports/<name>.rb, and multiple report names should be
            comma-separated (whitespace is okay)."
        ],
        :reportdir => {:default => "$vardir/reports",
                :mode => 0750,
                :owner => "$user",
                :group => "$group",
                :desc => "The directory in which to store reports
                    received from the client.  Each client gets a separate
                    subdirectory."}
    )
    self.setdefaults("puppetd",
        :puppetdlockfile => [ "$statedir/puppetdlock",
            "A lock file to temporarily stop puppetd from doing anything."],
        :usecacheonfailure => [true,
            "Whether to use the cached configuration when the remote
            configuration will not compile.  This option is useful for testing
            new configurations, where you want to fix the broken configuration
            rather than reverting to a known-good one."
        ],
        :ignorecache => [false,
            "Ignore cache and always recompile the configuration.  This is
            useful for testing new configurations, where the local cache may in
            fact be stale even if the timestamps are up to date - if the facts
            change or if the server changes."
        ],
        :downcasefacts => [false,
            "Whether facts should be made all lowercase when sent to the server."]
    )

    self.setdefaults(:puppetd,
        :configtimeout => [120,
            "How long the client should wait for the configuration to be retrieved
            before considering it a failure.  This can help reduce flapping if too
            many clients contact the server at one time."
        ],
        :reportserver => ["$server",
            "The server to which to send transaction reports."
        ],
        :report => [false,
            "Whether to send reports after every transaction."
        ]
    )

    # Plugin information.
    self.setdefaults("puppet",
        :pluginpath => ["$vardir/plugins",
            "Where Puppet should look for plugins.  Multiple directories should
            be colon-separated, like normal PATH variables."],
        :plugindest => ["$vardir/plugins",
            "Where Puppet should store plugins that it pulls down from the central
            server."],
        :pluginsource => ["puppet://$server/plugins",
            "From where to retrieve plugins.  The standard Puppet ``file`` type
             is used for retrieval, so anything that is a valid file source can
             be used here."],
        :pluginsync => [false,
            "Whether plugins should be synced with the central server."],
        :pluginsignore => [".svn CVS",
            "What files to ignore when pulling down plugins."]
    )

    # Central fact information.
    self.setdefaults("puppet",
        :factpath => ["$vardir/facts",
            "Where Puppet should look for facts.  Multiple directories should
            be colon-separated, like normal PATH variables."],
        :factdest => ["$vardir/facts",
            "Where Puppet should store facts that it pulls down from the central
            server."],
        :factsource => ["puppet://$server/facts",
            "From where to retrieve facts.  The standard Puppet ``file`` type
             is used for retrieval, so anything that is a valid file source can
             be used here."],
        :factsync => [false,
            "Whether facts should be synced with the central server."],
        :factsignore => [".svn CVS",
            "What files to ignore when pulling down facts."]
    )

    self.setdefaults(:reporting,
        :tagmap => ["$confdir/tagmail.conf",
            "The mapping between reporting tags and email addresses."],
        :sendmail => [%x{which sendmail 2>/dev/null}.chomp,
            "Where to find the sendmail binary with which to send email."],
        :reportfrom => ["report@" + [Facter["hostname"].value, Facter["domain"].value].join("."),
            "The 'from' email address for the reports."],
        :smtpserver => ["none",
            "The server through which to send email reports."]
    )
end

# $Id$
