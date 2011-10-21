# The majority of the system configuration parameters are set in this file.
module Puppet
    # If we're running the standalone puppet process as a non-root user,
    # use basedirs that are in the user's home directory.
    conf = nil
    var = nil
    name = $0.gsub(/.+#{File::SEPARATOR}/,'').sub(/\.rb$/, '')

    # Make File.expand_path happy
    require 'etc'
    ENV["HOME"] ||= Etc.getpwuid(Process.uid).dir

    if name != "puppetmasterd" and Puppet::Util::SUIDManager.uid != 0
        conf = File.expand_path("~/.puppet")
        var = File.expand_path("~/.puppet/var")
    else
        # Else, use system-wide directories.
        conf = "/etc/puppet"
        var = "/var/puppet"
    end

    self.setdefaults(:main,
        :confdir => [conf, "The main Puppet configuration directory.  The default for this parameter is calculated based on the user.  If the process
        is runnig as root or the user that ``puppetmasterd`` is supposed to run as, it defaults to a system directory, but if it's running as any other user,
        it defaults to being in ``~``."],
        :vardir => [var, "Where Puppet stores dynamic and growing data.  The default for this parameter is calculated specially, like `confdir`_."],
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
    setdefaults(:main, :logdir => logopts)
    
    # This name hackery is necessary so that the rundir is set reasonably during
    # unit tests.
    if Process.uid == 0 and %w{puppetd puppetmasterd}.include?(self.name)
        rundir = "/var/run/puppet"
    else
        rundir = "$vardir/run"
    end

    self.setdefaults(:main,
        :trace => [false, "Whether to print stack traces on some errors"],
        :autoflush => [false, "Whether log files should always flush to disk."],
        :syslogfacility => ["daemon", "What syslog facility to use when logging to
            syslog.  Syslog has a fixed list of valid facilities, and you must
            choose one of those; you cannot just make one up."],
        :statedir => { :default => "$vardir/state",
            :mode => 01755,
            :desc => "The directory where Puppet state is stored.  Generally,
                this directory can be removed without causing harm (although it
                might result in spurious service restarts)."
        },
        :ssldir => {
            :default => "$confdir/ssl",
            :mode => 0771,
            :owner => "root",
            :desc => "Where SSL certificates are kept."
        },
        :rundir => { 
            :default => rundir,
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
            :call_on_define => true, # Call our hook with the default value, so we always get the libdir set.
            :hook => proc do |value|
                ENV["PATH"] = value unless value == "none"

                paths = ENV["PATH"].split(File::PATH_SEPARATOR)
                %w{/usr/sbin /sbin}.each do |path|
                    unless paths.include?(path)
                        ENV["PATH"] += File::PATH_SEPARATOR + path
                    end
                end
                value
            end
        },
        :libdir => {:default => "$vardir/lib",
            :desc => "An extra search path for Puppet.  This is only useful
                for those files that Puppet will load on demand, and is only
                guaranteed to work for those cases.  In fact, the autoload
                mechanism is responsible for making sure this directory
                is in Ruby's search path",
            :call_on_define => true, # Call our hook with the default value, so we always get the libdir set.
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
        ],
        :environment => {:default => "production", :desc => "The environment Puppet is running in.  For clients
            (e.g., ``puppetd``) this determines the environment itself, which
            is used to find modules and much more.  For servers (i.e.,
            ``puppetmasterd``) this provides the default environment for nodes
            we know nothing about."
        },
        :diff_args => ["", "Which arguments to pass to the diff command when printing differences between files."],
        :diff => ["diff", "Which diff command to use when printing differences between files."],
        :show_diff => [false, "Whether to print a contextual diff when files are being replaced.  The diff
            is printed on stdout, so this option is meaningless unless you are running Puppet interactively.
            This feature currently requires the ``diff/lcs`` Ruby library."],
        :daemonize => { :default => true,
            :desc => "Send the process into the background.  This is the default.",
            :short => "D"
        },
        :maximum_uid => [4294967290, "The maximum allowed UID.  Some platforms use negative UIDs
            but then ship with tools that do not know how to handle signed ints, so the UIDs show up as
            huge numbers that can then not be fed back into the system.  This is a hackish way to fail in a
            slightly more useful way when that happens."],
        :node_terminus => ["plain", "Where to find information about nodes."]
    )

    hostname = Facter["hostname"].value
    domain = Facter["domain"].value
    if domain and domain != ""
        fqdn = [hostname, domain].join(".")
    else
        fqdn = hostname
    end

    Puppet.setdefaults(:ssl,
        # We have to downcase the fqdn, because the current ssl stuff (as oppsed to in master) doesn't have good facilities for 
        # manipulating naming.
        :certname => {:default => fqdn.downcase, :desc => "The name to use when handling certificates.  Defaults
            to the fully qualified domain name.",
            :call_on_define => true, # Call our hook with the default value, so we're always downcased
            :hook => proc { |value| raise(ArgumentError, "Certificate names must be lower case; see #1168") unless value == value.downcase }},
        :certdnsnames => {:default => '',
            :desc => "The DNS names on the Server certificate as a
            colon-separated list.  If it's anything other than an empty string,
            it will be used as an alias in the created certificate.  By
            default, only the server gets an alias set up, and only for
            'puppet'.",
            :hook => proc { |value|
                msg = <<WARN
The `certdnsnames` setting is no longer functional, after CVE-2011-3872. We
ignore the value completely. See http://puppetlabs.com/security/cve/3872 for
more information"
WARN
                puts msg if value and value != ''
            }
        },
        :certdir => ["$ssldir/certs", "The certificate directory."],
        :publickeydir => ["$ssldir/public_keys", "The public key directory."],
        :privatekeydir => { :default => "$ssldir/private_keys",
            :mode => 0750,
            :desc => "The private key directory."
        },
        :privatedir => { :default => "$ssldir/private",
            :mode => 0750,
            :desc => "Where the client stores private certificate information."
        },
        :passfile => { :default => "$privatedir/password",
            :mode => 0640,
            :desc => "Where puppetd stores the password for its private key.
                Generally unused."
        },
        :hostcsr => { :default => "$ssldir/csr_$certname.pem",
            :mode => 0644,
            :desc => "Where individual hosts store and look for their certificates."
        },
        :hostcert => { :default => "$certdir/$certname.pem",
            :mode => 0644,
            :desc => "Where individual hosts store and look for their certificates."
        },
        :hostprivkey => { :default => "$privatekeydir/$certname.pem",
            :mode => 0600,
            :desc => "Where individual hosts store and look for their private key."
        },
        :hostpubkey => { :default => "$publickeydir/$certname.pem",
            :mode => 0644,
            :desc => "Where individual hosts store and look for their public key."
        },
        :localcacert => { :default => "$certdir/ca.pem",
            :mode => 0644,
            :desc => "Where each client stores the CA certificate."
        }
    )

    setdefaults(:ca,
        :cadir => {  :default => "$ssldir/ca",
            :owner => "$user",
            :group => "$group",
            :mode => 0770,
            :desc => "The root directory for the certificate authority."
        },
        :cacert => { :default => "$cadir/ca_crt.pem",
            :owner => "$user",
            :group => "$group",
            :mode => 0660,
            :desc => "The CA certificate."
        },
        :cakey => { :default => "$cadir/ca_key.pem",
            :owner => "$user",
            :group => "$group",
            :mode => 0660,
            :desc => "The CA private key."
        },
        :capub => { :default => "$cadir/ca_pub.pem",
            :owner => "$user",
            :group => "$group",
            :desc => "The CA public key."
        },
        :cacrl => { :default => "$cadir/ca_crl.pem",
            :owner => "$user",
            :group => "$group",
            :mode => 0664,
            :desc => "The certificate revocation list (CRL) for the CA. Set this to 'false' if you do not want to use a CRL."
        },
        :caprivatedir => { :default => "$cadir/private",
            :owner => "$user",
            :group => "$group",
            :mode => 0770,
            :desc => "Where the CA stores private certificate information."
        },
        :csrdir => { :default => "$cadir/requests",
            :owner => "$user",
            :group => "$group",
            :desc => "Where the CA stores certificate requests"
        },
        :signeddir => { :default => "$cadir/signed",
            :owner => "$user",
            :group => "$group",
            :mode => 0770,
            :desc => "Where the CA stores signed certificates."
        },
        :capass => { :default => "$caprivatedir/ca.pass",
            :owner => "$user",
            :group => "$group",
            :mode => 0660,
            :desc => "Where the CA stores the password for the private key"
        },
        :serial => { :default => "$cadir/serial",
            :owner => "$user",
            :group => "$group",
            :mode => 0600,
            :desc => "Where the serial number for certificates is stored."
        },
        :autosign => { :default => "$confdir/autosign.conf",
            :mode => 0644,
            :desc => "Whether to enable autosign.  Valid values are true (which
                autosigns any key request, and is a very bad idea), false (which
                never autosigns any key request), and the path to a file, which
                uses that configuration file to determine which keys to sign."},
        :ca_days => ["", "How long a certificate should be valid. 
                 This parameter is deprecated, use ca_ttl instead"],
        :ca_ttl => ["5y", "The default TTL for new certificates; valid values 
                must be an integer, optionally followed by one of the units 
                'y' (years of 365 days), 'd' (days), 'h' (hours), or 
                's' (seconds). The unit defaults to seconds. If this parameter
                is set, ca_days is ignored. Examples are '3600' (one hour) 
                and '1825d', which is the same as '5y' (5 years) "],
        :ca_md => ["md5", "The type of hash used in certificates."],
        :req_bits => [2048, "The bit length of the certificates."],
        :keylength => [1024, "The bit length of keys."],
        :cert_inventory => {
            :default => "$cadir/inventory.txt",
            :mode => 0644,
            :owner => "$user",
            :group => "$group",
            :desc => "A Complete listing of all certificates"
        }
    )

    # Define the config default.
    self.setdefaults(self.settings[:name],
        :config => ["$confdir/puppet.conf",
            "The configuration file for #{Puppet[:name]}."],
        :pidfile => ["", "The pid file"],
        :bindaddress => ["", "The address to bind to.  Mongrel servers
            default to 127.0.0.1 and WEBrick defaults to 0.0.0.0."],
        :servertype => ["webrick", "The type of server to use.  Currently supported
            options are webrick and mongrel.  If you use mongrel, you will need
            a proxy in front of the process or processes, since Mongrel cannot
            speak SSL."]
    )

    self.setdefaults(:puppetmasterd,
        :user => ["puppet", "The user puppetmasterd should run as."],
        :group => ["puppet", "The group puppetmasterd should run as."],
        :manifestdir => ["$confdir/manifests",
            "Where puppetmasterd looks for its manifests."],
        :manifest => ["$manifestdir/site.pp",
            "The entry-point manifest for puppetmasterd."],
        :code => ["", "Code to parse directly.  This is essentially only used
            by ``puppet``, and should only be set if you're writing your own Puppet
            executable"],
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
           and sets the 'hostname', 'fqdn' and 'domain' facts for use in the manifest, 
           in particular for determining which 'node' statement applies to the client. 
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
            directories." ],
        :ssl_client_header => ["HTTP_X_CLIENT_DN", "The header containing an authenticated
            client's SSL DN.  Only used with Mongrel.  This header must be set by the proxy
            to the authenticated client's SSL DN (e.g., ``/CN=puppet.reductivelabs.com``).
            See http://reductivelabs.com/puppet/trac/wiki/UsingMongrel for more information."],
        :ssl_client_verify_header => ["HTTP_X_CLIENT_VERIFY", "The header containing the status
            message of the client verification. Only used with Mongrel.  This header must be set by the proxy
            to 'SUCCESS' if the client successfully authenticated, and anything else otherwise.
            See http://reductivelabs.com/puppet/trac/wiki/UsingMongrel for more information."],
        # To make sure this directory is created before we try to use it on the server, we need
        # it to be in the server section (#1138).
        :yamldir => {:default => "$vardir/yaml", :owner => "$user", :group => "$user", :mode => "750",
            :desc => "The directory in which YAML data is stored, usually in a subdirectory."},
        :clientyamldir => {:default => "$vardir/client_yaml", :mode => "750",
            :desc => "The directory in which client-side YAML data is stored."}
    )

    self.setdefaults(:puppetd,
        :localconfig => { :default => "$statedir/localconfig",
            :owner => "root",
            :mode => 0660,
            :desc => "Where puppetd caches the local configuration.  An
                extension indicating the cache format is added automatically."},
        :statefile => { :default => "$statedir/state.yaml",
            :mode => 0660,
            :desc => "Where puppetd and puppetmasterd store state associated
                with the running configuration.  In the case of puppetmasterd,
                this file reflects the state discovered through interacting
                with clients."
            },
        :classfile => { :default => "$statedir/classes.txt",
            :owner => "root",
            :mode => 0644,
            :desc => "The file in which puppetd stores a list of the classes
                associated with the retrieved configuration.  Can be loaded in
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
        :http_proxy_host => ["none",
            "The HTTP proxy host to use for outgoing connections.  Note: You
            may need to use a FQDN for the server hostname when using a proxy."],
        :http_proxy_port => [3128,
            "The HTTP proxy port to use for outgoing connections"],
        :http_enable_post_connection_check => [true,
            "Boolean; wheter or not puppetd should validate the server
            SSL certificate against the request hostname."],
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
        :ca_port => ["$masterport", "The port to use for the certificate authority."],
        :catalog_format => ["yaml", "What format to use to dump the catalog.  Only supports
            'marshal' and 'yaml'.  Only matters on the client, since it asks the server
            for a specific format."]
    )
        
    self.setdefaults(:filebucket,
        :clientbucketdir => {
            :default => "$vardir/clientbucket",
            :mode => 0750,
            :desc => "Where FileBucket files are stored locally."
        }
    )
    self.setdefaults(:fileserver,
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
    self.setdefaults(:puppetd,
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
            "Whether facts should be made all lowercase when sent to the server."],
        :dynamicfacts => ["memorysize,memoryfree,swapsize,swapfree",
            "Facts that are dynamic; these facts will be ignored when deciding whether
            changed facts should result in a recompile.  Multiple facts should be
            comma-separated."],
        :splaylimit => ["$runinterval",
            "The maximum time to delay before runs.  Defaults to being the same as the
            run interval."],
        :splay => [false,
            "Whether to sleep for a pseudo-random (but consistent) amount of time before
            a run."]
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
    self.setdefaults(:main,
        :pluginpath => ["$vardir/plugins",
            "Where Puppet should look for plugins.  Multiple directories should
            be colon-separated, like normal PATH variables.  As of 0.23.1, this
            option is deprecated; download your custom libraries to the $libdir
            instead."],
        :plugindest => ["$libdir",
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
    self.setdefaults(:main,
        :factpath => {:default => "$vardir/facts",
            :desc => "Where Puppet should look for facts.  Multiple directories should
                be colon-separated, like normal PATH variables.",
            :call_on_define => true, # Call our hook with the default value, so we always get the value added to facter.
            :hook => proc { |value| Facter.search(value) if Facter.respond_to?(:search) }},
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

    self.setdefaults(:tagmail,
        :tagmap => ["$confdir/tagmail.conf",
            "The mapping between reporting tags and email addresses."],
        :sendmail => [%x{which sendmail 2>/dev/null}.chomp,
            "Where to find the sendmail binary with which to send email."],
        :reportfrom => ["report@" + [Facter["hostname"].value, Facter["domain"].value].join("."),
            "The 'from' email address for the reports."],
        :smtpserver => ["none",
            "The server through which to send email reports."]
    )

    self.setdefaults(:rails,
        :dblocation => { :default => "$statedir/clientconfigs.sqlite3",
            :mode => 0660,
            :owner => "$user",
            :group => "$group",
            :desc => "The database cache for client configurations.  Used for
                querying within the language."
        },
        :dbadapter => [ "sqlite3", "The type of database to use." ],
        :dbmigrate => [ false, "Whether to automatically migrate the database." ],
        :dbname => [ "puppet", "The name of the database to use." ],
        :dbserver => [ "localhost", "The database server for Client caching. Only
            used when networked databases are used."],
        :dbuser => [ "puppet", "The database user for Client caching. Only
            used when networked databases are used."],
        :dbpassword => [ "puppet", "The database password for Client caching. Only
            used when networked databases are used."],
        :dbsocket => [ "", "The database socket location. Only used when networked
            databases are used.  Will be ignored if the value is an empty string."],
        :railslog => {:default => "$logdir/rails.log",
            :mode => 0600,
            :owner => "$user",
            :group => "$group",
            :desc => "Where Rails-specific logs are sent"
        },
        :rails_loglevel => ["info", "The log level for Rails connections.  The value must be
            a valid log level within Rails.  Production environments normally use ``info``
            and other environments normally use ``debug``."]
    )

    setdefaults(:graphing,
        :graph => [false, "Whether to create dot graph files for the different
            configuration graphs.  These dot files can be interpreted by tools
            like OmniGraffle or dot (which is part of ImageMagick)."],
        :graphdir => ["$statedir/graphs", "Where to store dot-outputted graphs."]
    )

    setdefaults(:transaction,
        :tags => ["", "Tags to use to find resources.  If this is set, then
            only resources tagged with the specified tags will be applied.
            Values must be comma-separated."],
        :evaltrace => [false, "Whether each resource should log when it is
            being evaluated.  This allows you to interactively see exactly
            what is being done."],
        :summarize => [false,
            "Whether to print a transaction summary."
        ]
    )

    setdefaults(:parser,
        :typecheck => [true, "Whether to validate types during parsing."],
        :paramcheck => [true, "Whether to validate parameters during parsing."]
    )
    
    setdefaults(:main,
        :casesensitive => [false,
            "Whether matching in case statements and selectors
            should be case-sensitive.  Case insensitivity is
            handled by downcasing all values before comparison."],
        :external_nodes => ["none",
            "An external command that can produce node information.  The output
            must be a YAML dump of a hash, and that hash must have one or both of
            ``classes`` and ``parameters``, where ``classes`` is an array and
            ``parameters`` is a hash.  For unknown nodes, the commands should
            exit with a non-zero exit code.

            This command makes it straightforward to store your node mapping
            information in other data sources like databases."])

    setdefaults(:ldap,
        :ldapnodes => [false,
            "Whether to search for node configurations in LDAP.  See
            http://reductivelabs.com/puppet/trac/wiki/LdapNodes/ for more information."],
        :ldapssl => [false,
            "Whether SSL should be used when searching for nodes.
            Defaults to false because SSL usually requires certificates
            to be set up on the client side."],
        :ldaptls => [false,
            "Whether TLS should be used when searching for nodes.
            Defaults to false because TLS usually requires certificates
            to be set up on the client side."],
        :ldapserver => ["ldap",
            "The LDAP server.  Only used if ``ldapnodes`` is enabled."],
        :ldapport => [389,
            "The LDAP port.  Only used if ``ldapnodes`` is enabled."],
        :ldapstring => ["(&(objectclass=puppetClient)(cn=%s))",
            "The search string used to find an LDAP node."],
        :ldapclassattrs => ["puppetclass",
            "The LDAP attributes to use to define Puppet classes.  Values
            should be comma-separated."],
        :ldapstackedattrs => ["puppetvar",
            "The LDAP attributes that should be stacked to arrays by adding
            the values in all hierarchy elements of the tree.  Values
            should be comma-separated."],
        :ldapattrs => ["all",
            "The LDAP attributes to include when querying LDAP for nodes.  All
            returned attributes are set as variables in the top-level scope.
            Multiple values should be comma-separated.  The value 'all' returns
            all attributes."],
        :ldapparentattr => ["parentnode",
            "The attribute to use to define the parent node."],
        :ldapuser => ["",
            "The user to use to connect to LDAP.  Must be specified as a
            full DN."],
        :ldappassword => ["",
            "The password to use to connect to LDAP."],
        :ldapbase => ["",
            "The search base for LDAP searches.  It's impossible to provide
            a meaningful default here, although the LDAP libraries might
            have one already set.  Generally, it should be the 'ou=Hosts'
            branch under your main directory."]
    )

    setdefaults(:puppetmasterd,
        :storeconfigs => [false,
            "Whether to store each client's configuration.  This
             requires ActiveRecord from Ruby on Rails."]
    )

    # This doesn't actually work right now.
    setdefaults(:parser,
        :lexical => [false, "Whether to use lexical scoping (vs. dynamic)."],
        :templatedir => ["$vardir/templates",
            "Where Puppet looks for template files.  Can be a list of colon-seperated
             directories."
        ]
    )

    setdefaults(:main,
        :filetimeout => [ 15,
            "The minimum time to wait (in seconds) between checking for updates in
            configuration files.  This timeout determines how quickly Puppet checks whether
            a file (such as manifests or templates) has changed on disk."
        ]
    )

    setdefaults(:metrics,
        :rrddir => {:default => "$vardir/rrd",
            :owner => "$user",
            :group => "$group",
            :desc => "The directory where RRD database files are stored.
                Directories for each reporting host will be created under
                this directory."
        },
        :rrdgraph => [false, "Whether RRD information should be graphed."],
        :rrdinterval => ["$runinterval", "How often RRD should expect data.
            This should match how often the hosts report back to the server."]
    )
end

