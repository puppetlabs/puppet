# The majority of the system configuration parameters are set in this file.
module Puppet
    # If we're running the standalone puppet process as a non-root user,
    # use basedirs that are in the user's home directory.
    conf = nil
    var = nil
    if self.name != "puppetmasterd" and Puppet::SUIDManager.uid != 0
        conf = File.expand_path("~/.puppet")
        var = File.expand_path("~/.puppet/var")
    else
        # Else, use system-wide directories.
        conf = "/etc/puppet"
        var = "/var/puppet"
    end

    self.setdefaults(:puppet,
        :confdir => [conf, "The main Puppet configuration directory."],
        :vardir => [var, "Where Puppet stores dynamic and growing data."]
    )

    if self.name == "puppetmasterd"
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
        :rundir => { :default => "/var/run/puppet",
            :mode => 01777,
            :desc => "Where Puppet PID files are kept."
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
        }
    )

    # Define the config default.
    self.setdefaults(self.name,
        :config => ["$confdir/#{self.name}.conf",
            "The configuration file for #{self.name}."]
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
           reported in its facts)"]
    )

    self.setdefaults("puppetd",
        :localconfig => { :default => "$confdir/localconfig",
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
            "How often puppetd applies the client configuration; in seconds"]
    )
end

# $Id$
