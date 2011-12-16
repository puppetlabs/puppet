# The majority of the system configuration parameters are set in this file.
module Puppet
  setdefaults(:main,
    :confdir => [Puppet.run_mode.conf_dir, "The main Puppet configuration directory.  The default for this parameter is calculated based on the user.  If the process
    is running as root or the user that Puppet is supposed to run as, it defaults to a system directory, but if it's running as any other user,
    it defaults to being in the user's home directory."],
    :vardir => [Puppet.run_mode.var_dir, "Where Puppet stores dynamic and growing data.  The default for this parameter is calculated specially, like `confdir`_."],
    :name => [Puppet.application_name.to_s, "The name of the application, if we are running as one.  The
      default is essentially $0 without the path or `.rb`."],
    :run_mode => [Puppet.run_mode.name.to_s, "The effective 'run mode' of the application: master, agent, or user."]
  )

  setdefaults(:main, :logdir => Puppet.run_mode.logopts)

  setdefaults(:main,
    :trace => [false, "Whether to print stack traces on some errors"],
    :autoflush => {
      :default => false,
      :desc    => "Whether log files should always flush to disk.",
      :hook    => proc { |value| Log.autoflush = value }
    },
    :syslogfacility => ["daemon", "What syslog facility to use when logging to
      syslog.  Syslog has a fixed list of valid facilities, and you must
      choose one of those; you cannot just make one up."],
    :statedir => { :default => "$vardir/state",
      :mode => 01755,
      :desc => "The directory where Puppet state is stored.  Generally,
        this directory can be removed without causing harm (although it
        might result in spurious service restarts)."
    },
    :rundir => {
      :default => Puppet.run_mode.run_dir,
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
    :color => {
      :default => (Puppet.features.microsoft_windows? ? "false" : "ansi"),
      :type    => :setting,
      :desc    => "Whether to use colors when logging to the console.
      Valid values are `ansi` (equivalent to `true`), `html` (mostly
      used during testing with TextMate), and `false`, which produces
      no color.",
    },
    :mkusers => [false,
      "Whether to create the necessary user and group that puppet agent will
      run as."],
    :manage_internal_file_permissions => [true,
      "Whether Puppet should manage the owner, group, and mode of files
      it uses internally"
      ],
    :onetime => {:default => false,
      :desc => "Run the configuration once, rather than as a long-running
      daemon. This is useful for interactively running puppetd.",
      :short => 'o'
      },
    :path => {:default => "none",
      :desc => "The shell search path.  Defaults to whatever is inherited
        from the parent process.",
      :call_on_define => true, # Call our hook with the default value, so we always get the libdir set.
      :hook => proc do |value|
        ENV["PATH"] = "" if ENV["PATH"].nil?
        ENV["PATH"] = value unless value == "none"
        paths = ENV["PATH"].split(File::PATH_SEPARATOR)
        %w{/usr/sbin /sbin}.each do |path|
          ENV["PATH"] += File::PATH_SEPARATOR + path unless paths.include?(path)
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
        $LOAD_PATH.delete(@oldlibdir) if defined?(@oldlibdir) and $LOAD_PATH.include?(@oldlibdir)
        @oldlibdir = value
        $LOAD_PATH << value
      end
    },
    :ignoreimport => [false, "A parameter that can be used in commit
      hooks, since it enables you to parse-check a single file rather
      than requiring that all files exist."],
    :authconfig => [ "$confdir/namespaceauth.conf",
      "The configuration file that defines the rights to the different
      namespaces and methods.  This can be used as a coarse-grained
      authorization system for both `puppet agent` and `puppet master`."
    ],
    :environment => {:default => "production", :desc => "The environment Puppet is running in.  For clients
      (e.g., `puppet agent`) this determines the environment itself, which
      is used to find modules and much more.  For servers (i.e., `puppet master`) this provides the default environment for nodes
      we know nothing about."
    },
    :diff_args => ["-u", "Which arguments to pass to the diff command when printing differences between files."],
    :diff => ["diff", "Which diff command to use when printing differences between files."],
    :show_diff => [false, "Whether to log and report a contextual diff when files are being replaced.  This causes
      partial file contents to pass through Puppet's normal logging and reporting system, so this setting should be
      used with caution if you are sending Puppet's reports to an insecure destination.
      This feature currently requires the `diff/lcs` Ruby library."],
    :daemonize => {
      :default => (Puppet.features.microsoft_windows? ? false : true),
      :desc => "Send the process into the background.  This is the default.",
      :short => "D",
      :hook => proc do |value|
        if value and Puppet.features.microsoft_windows?
          raise "Cannot daemonize on Windows"
        end
      end
    },
    :maximum_uid => [4294967290, "The maximum allowed UID.  Some platforms use negative UIDs
      but then ship with tools that do not know how to handle signed ints, so the UIDs show up as
      huge numbers that can then not be fed back into the system.  This is a hackish way to fail in a
      slightly more useful way when that happens."],
    :route_file => ["$confdir/routes.yaml", "The YAML file containing indirector route configuration."],
    :node_terminus => ["plain", "Where to find information about nodes."],
    :catalog_terminus => ["compiler", "Where to get node catalogs.  This is useful to change if, for instance,
      you'd like to pre-compile catalogs and store them in memcached or some other easily-accessed store."],
    :facts_terminus => {
      :default => Puppet.application_name.to_s == "master" ? 'yaml' : 'facter',
      :desc => "The node facts terminus.",
      :hook => proc do |value|
        require 'puppet/node/facts'
        # Cache to YAML if we're uploading facts away
        if %w[rest inventory_service].include? value.to_s
          Puppet::Node::Facts.indirection.cache_class = :yaml
        end
      end
    },
    :inventory_terminus => [ "$facts_terminus", "Should usually be the same as the facts terminus" ],
    :httplog => { :default => "$logdir/http.log",
      :owner => "root",
      :mode => 0640,
      :desc => "Where the puppet agent web server logs."
    },
    :http_proxy_host => ["none",
      "The HTTP proxy host to use for outgoing connections.  Note: You
      may need to use a FQDN for the server hostname when using a proxy."],
    :http_proxy_port => [3128, "The HTTP proxy port to use for outgoing connections"],
    :filetimeout => [ 15,
      "The minimum time to wait (in seconds) between checking for updates in
      configuration files.  This timeout determines how quickly Puppet checks whether
      a file (such as manifests or templates) has changed on disk."
    ],
    :queue_type => ["stomp", "Which type of queue to use for asynchronous processing."],
    :queue_type => ["stomp", "Which type of queue to use for asynchronous processing."],
    :queue_source => ["stomp://localhost:61613/", "Which type of queue to use for asynchronous processing.  If your stomp server requires
      authentication, you can include it in the URI as long as your stomp client library is at least 1.1.1"],
    :async_storeconfigs => {:default => false, :desc => "Whether to use a queueing system to provide asynchronous database integration.
      Requires that `puppetqd` be running and that 'PSON' support for ruby be installed.",
      :hook => proc do |value|
        if value
          # This reconfigures the terminii for Node, Facts, and Catalog
          Puppet.settings[:storeconfigs] = true

          # But then we modify the configuration
          Puppet::Resource::Catalog.indirection.cache_class = :queue
        else
          raise "Cannot disable asynchronous storeconfigs in a running process"
        end
      end
    },
    :thin_storeconfigs => {:default => false, :desc =>
      "Boolean; wether storeconfigs store in the database only the facts and exported resources.
      If true, then storeconfigs performance will be higher and still allow exported/collected
      resources, but other usage external to Puppet might not work",
      :hook => proc do |value|
        Puppet.settings[:storeconfigs] = true if value
        end
      },
    :config_version => ["", "How to determine the configuration version.  By default, it will be the
      time that the configuration is parsed, but you can provide a shell script to override how the
      version is determined.  The output of this script will be added to every log message in the
      reports, allowing you to correlate changes on your hosts to the source version on the server."],
    :zlib => [true,
      "Boolean; whether to use the zlib library",
    ],
    :prerun_command => ["", "A command to run before every agent run.  If this command returns a non-zero
      return code, the entire Puppet run will fail."],
    :postrun_command => ["", "A command to run after every agent run.  If this command returns a non-zero
      return code, the entire Puppet run will be considered to have failed, even though it might have
      performed work during the normal run."],
    :freeze_main => [false, "Freezes the 'main' class, disallowing any code to be added to it.  This
      essentially means that you can't have any code outside of a node, class, or definition other
      than in the site manifest."]
  )
  Puppet.setdefaults(:module_tool,
    :module_repository  => ['http://forge.puppetlabs.com', "The module repository"],
    :module_working_dir => ['$vardir/puppet-module', "The directory into which module tool data is stored"]
  )

  hostname = Facter["hostname"].value
  domain = Facter["domain"].value
  if domain and domain != ""
    fqdn = [hostname, domain].join(".")
  else
    fqdn = hostname
  end


    Puppet.setdefaults(
    :main,

    # We have to downcase the fqdn, because the current ssl stuff (as oppsed to in master) doesn't have good facilities for
    # manipulating naming.
    :certname => {:default => fqdn.downcase, :desc => "The name to use when handling certificates.  Defaults
      to the fully qualified domain name.",
      :call_on_define => true, # Call our hook with the default value, so we're always downcased
      :hook => proc { |value| raise(ArgumentError, "Certificate names must be lower case; see #1168") unless value == value.downcase }},
    :certdnsnames => {
      :default => '',
      :hook    => proc do |value|
        unless value.nil? or value == '' then
          Puppet.warning <<WARN
The `certdnsnames` setting is no longer functional,
after CVE-2011-3872. We ignore the value completely.

For your own certificate request you can set `dns_alt_names` in the
configuration and it will apply locally.  There is no configuration option to
set DNS alt names, or any other `subjectAltName` value, for another nodes
certificate.

Alternately you can use the `--dns_alt_names` command line option to set the
labels added while generating your own CSR.
WARN
        end
      end,
      :desc    => <<EOT
The `certdnsnames` setting is no longer functional,
after CVE-2011-3872. We ignore the value completely.

For your own certificate request you can set `dns_alt_names` in the
configuration and it will apply locally.  There is no configuration option to
set DNS alt names, or any other `subjectAltName` value, for another nodes
certificate.

Alternately you can use the `--dns_alt_names` command line option to set the
labels added while generating your own CSR.
EOT
    },
    :dns_alt_names => {
      :default => '',
      :desc    => <<EOT,
The comma-separated list of alternative DNS names to use for the local host.

When the node generates a CSR for itself, these are added to the request
as the desired `subjectAltName` in the certificate: additional DNS labels
that the certificate is also valid answering as.

This is generally required if you use a non-hostname `certname`, or if you
want to use `puppet kick` or `puppet resource -H` and the primary certname
does not match the DNS name you use to communicate with the host.

This is unnecessary for agents, unless you intend to use them as a server for
`puppet kick` or remote `puppet resource` management.

It is rarely necessary for servers; it is usually helpful only if you need to
have a pool of multiple load balanced masters, or for the same master to
respond on two physically separate networks under different names.
EOT
    },
    :certdir => {
      :default => "$ssldir/certs",
      :owner => "service",
      :desc => "The certificate directory."
    },
    :ssldir => {
      :default => "$confdir/ssl",
      :mode => 0771,
      :owner => "service",
      :desc => "Where SSL certificates are kept."
    },
    :publickeydir => {
      :default => "$ssldir/public_keys",
      :owner => "service",
      :desc => "The public key directory."
    },
    :requestdir => {
      :default => "$ssldir/certificate_requests",
      :owner => "service",
      :desc => "Where host certificate requests are stored."
    },
    :privatekeydir => { :default => "$ssldir/private_keys",
      :mode => 0750,
      :owner => "service",
      :desc => "The private key directory."
    },
    :privatedir => { :default => "$ssldir/private",
      :mode => 0750,
      :owner => "service",
      :desc => "Where the client stores private certificate information."
    },
    :passfile => { :default => "$privatedir/password",
      :mode => 0640,
      :owner => "service",
      :desc => "Where puppet agent stores the password for its private key.
        Generally unused."
    },
    :hostcsr => { :default => "$ssldir/csr_$certname.pem",
      :mode => 0644,
      :owner => "service",
      :desc => "Where individual hosts store and look for their certificate requests."
    },
    :hostcert => { :default => "$certdir/$certname.pem",
      :mode => 0644,
      :owner => "service",
      :desc => "Where individual hosts store and look for their certificates."
    },
    :hostprivkey => { :default => "$privatekeydir/$certname.pem",
      :mode => 0600,
      :owner => "service",
      :desc => "Where individual hosts store and look for their private key."
    },
    :hostpubkey => { :default => "$publickeydir/$certname.pem",
      :mode => 0644,
      :owner => "service",
      :desc => "Where individual hosts store and look for their public key."
    },
    :localcacert => { :default => "$certdir/ca.pem",
      :mode => 0644,
      :owner => "service",
      :desc => "Where each client stores the CA certificate."
    },
    :hostcrl => { :default => "$ssldir/crl.pem",
      :mode => 0644,
      :owner => "service",
      :desc => "Where the host's certificate revocation list can be found.
        This is distinct from the certificate authority's CRL."
    },
    :certificate_revocation => [true, "Whether certificate revocation should be supported by downloading a Certificate Revocation List (CRL)
      to all clients.  If enabled, CA chaining will almost definitely not work."]
  )

    setdefaults(
    :ca,
    :ca_name => ["Puppet CA: $certname", "The name to use the Certificate Authority certificate."],
    :cadir => {  :default => "$ssldir/ca",
      :owner => "service",
      :group => "service",
      :mode => 0770,
      :desc => "The root directory for the certificate authority."
    },
    :cacert => { :default => "$cadir/ca_crt.pem",
      :owner => "service",
      :group => "service",
      :mode => 0660,
      :desc => "The CA certificate."
    },
    :cakey => { :default => "$cadir/ca_key.pem",
      :owner => "service",
      :group => "service",
      :mode => 0660,
      :desc => "The CA private key."
    },
    :capub => { :default => "$cadir/ca_pub.pem",
      :owner => "service",
      :group => "service",
      :desc => "The CA public key."
    },
    :cacrl => { :default => "$cadir/ca_crl.pem",
      :owner => "service",
      :group => "service",
      :mode => 0664,

      :desc => "The certificate revocation list (CRL) for the CA. Will be used if present but otherwise ignored.",
      :hook => proc do |value|
        if value == 'false'
          Puppet.warning "Setting the :cacrl to 'false' is deprecated; Puppet will just ignore the crl if yours is missing"
        end
      end
    },
    :caprivatedir => { :default => "$cadir/private",
      :owner => "service",
      :group => "service",
      :mode => 0770,
      :desc => "Where the CA stores private certificate information."
    },
    :csrdir => { :default => "$cadir/requests",
      :owner => "service",
      :group => "service",
      :desc => "Where the CA stores certificate requests"
    },
    :signeddir => { :default => "$cadir/signed",
      :owner => "service",
      :group => "service",
      :mode => 0770,
      :desc => "Where the CA stores signed certificates."
    },
    :capass => { :default => "$caprivatedir/ca.pass",
      :owner => "service",
      :group => "service",
      :mode => 0660,
      :desc => "Where the CA stores the password for the private key"
    },
    :serial => { :default => "$cadir/serial",
      :owner => "service",
      :group => "service",
      :mode => 0644,
      :desc => "Where the serial number for certificates is stored."
    },
    :autosign => { :default => "$confdir/autosign.conf",
      :mode => 0644,
      :desc => "Whether to enable autosign.  Valid values are true (which
        autosigns any key request, and is a very bad idea), false (which
        never autosigns any key request), and the path to a file, which
        uses that configuration file to determine which keys to sign."},
    :allow_duplicate_certs => [false, "Whether to allow a new certificate
      request to overwrite an existing certificate."],
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
      :owner => "service",
      :group => "service",
      :desc => "A Complete listing of all certificates"
    }
  )

  # Define the config default.

    setdefaults(
    Puppet.settings[:name],
    :config => ["$confdir/puppet.conf",
      "The configuration file for #{Puppet[:name]}."],
    :pidfile => ["$rundir/$name.pid", "The pid file"],
    :bindaddress => ["", "The address a listening server should bind to.  Mongrel servers
      default to 127.0.0.1 and WEBrick defaults to 0.0.0.0."],
    :servertype => {:default => "webrick", :desc => "The type of server to use.  Currently supported
      options are webrick and mongrel.  If you use mongrel, you will need
      a proxy in front of the process or processes, since Mongrel cannot
      speak SSL.",

      :call_on_define => true, # Call our hook with the default value, so we always get the correct bind address set.
      :hook => proc { |value|  value == "webrick" ? Puppet.settings[:bindaddress] = "0.0.0.0" : Puppet.settings[:bindaddress] = "127.0.0.1" if Puppet.settings[:bindaddress] == "" }
    }
  )

  setdefaults(:master,
    :user => ["puppet", "The user puppet master should run as."],
    :group => ["puppet", "The group puppet master should run as."],
    :manifestdir => ["$confdir/manifests", "Where puppet master looks for its manifests."],
    :manifest => ["$manifestdir/site.pp", "The entry-point manifest for puppet master."],
    :code => ["", "Code to parse directly.  This is essentially only used
      by `puppet`, and should only be set if you're writing your own Puppet
      executable"],
    :masterlog => { :default => "$logdir/puppetmaster.log",
      :owner => "service",
      :group => "service",
      :mode => 0660,
      :desc => "Where puppet master logs.  This is generally not used,
        since syslog is the default log destination."
    },
    :masterhttplog => { :default => "$logdir/masterhttp.log",
      :owner => "service",
      :group => "service",
      :mode => 0660,
      :create => true,
      :desc => "Where the puppet master web server logs."
    },
    :masterport => [8140, "Which port puppet master listens on."],
    :node_name => ["cert", "How the puppet master determines the client's identity
      and sets the 'hostname', 'fqdn' and 'domain' facts for use in the manifest,
      in particular for determining which 'node' statement applies to the client.
      Possible values are 'cert' (use the subject's CN in the client's
      certificate) and 'facter' (use the hostname that the client
      reported in its facts)"],
    :bucketdir => {
      :default => "$vardir/bucket",
      :mode => 0750,
      :owner => "service",
      :group => "service",
      :desc => "Where FileBucket files are stored."
    },
    :rest_authconfig => [ "$confdir/auth.conf",
      "The configuration file that defines the rights to the different
      rest indirections.  This can be used as a fine-grained
      authorization system for `puppet master`."
    ],
    :ca => [true, "Wether the master should function as a certificate authority."],
    :modulepath => {
      :default => "$confdir/modules#{File::PATH_SEPARATOR}/usr/share/puppet/modules",
      :desc => "The search path for modules as a list of directories separated by the '#{File::PATH_SEPARATOR}' character.",
      :type => :setting # We don't want this to be considered a file, since it's multiple files.
    },
    :ssl_client_header => ["HTTP_X_CLIENT_DN", "The header containing an authenticated
      client's SSL DN.  Only used with Mongrel.  This header must be set by the proxy
      to the authenticated client's SSL DN (e.g., `/CN=puppet.puppetlabs.com`).
      See http://projects.puppetlabs.com/projects/puppet/wiki/Using_Mongrel for more information."],
    :ssl_client_verify_header => ["HTTP_X_CLIENT_VERIFY", "The header containing the status
      message of the client verification. Only used with Mongrel.  This header must be set by the proxy
      to 'SUCCESS' if the client successfully authenticated, and anything else otherwise.
      See http://projects.puppetlabs.com/projects/puppet/wiki/Using_Mongrel for more information."],
    # To make sure this directory is created before we try to use it on the server, we need
    # it to be in the server section (#1138).
    :yamldir => {:default => "$vardir/yaml", :owner => "service", :group => "service", :mode => "750",
      :desc => "The directory in which YAML data is stored, usually in a subdirectory."},
    :server_datadir => {:default => "$vardir/server_data", :owner => "service", :group => "service", :mode => "750",
      :desc => "The directory in which serialized data is stored, usually in a subdirectory."},
    :reports => ["store",
      "The list of reports to generate.  All reports are looked for
      in `puppet/reports/name.rb`, and multiple report names should be
      comma-separated (whitespace is okay)."
    ],
    :reportdir => {:default => "$vardir/reports",
      :mode => 0750,
      :owner => "service",
      :group => "service",
      :desc => "The directory in which to store reports
        received from the client.  Each client gets a separate
        subdirectory."},
    :reporturl => ["http://localhost:3000/reports/upload",
      "The URL used by the http reports processor to send reports"],
    :fileserverconfig => ["$confdir/fileserver.conf", "Where the fileserver configuration is stored."],
    :strict_hostname_checking => [false, "Whether to only search for the complete
      hostname as it is in the certificate when searching for node information
      in the catalogs."]
  )

  setdefaults(:metrics,
    :rrddir => {:default => "$vardir/rrd",
      :mode => 0750,
      :owner => "service",
      :group => "service",
      :desc => "The directory where RRD database files are stored.
        Directories for each reporting host will be created under
        this directory."
    },
    :rrdinterval => ["$runinterval", "How often RRD should expect data.
      This should match how often the hosts report back to the server."]
  )

  setdefaults(:device,
    :devicedir =>  {:default => "$vardir/devices", :mode => "750", :desc => "The root directory of devices' $vardir"},
    :deviceconfig => ["$confdir/device.conf","Path to the device config file for puppet device"]
  )

  setdefaults(:agent,
    :node_name_value => { :default => "$certname",
      :desc => "The explicit value used for the node name for all requests the agent
        makes to the master. WARNING: This setting is mutually exclusive with
        node_name_fact.  Changing this setting also requires changes to the default
        auth.conf configuration on the Puppet Master.  Please see
        http://links.puppetlabs.com/node_name_value for more information."
    },
    :node_name_fact => { :default => "",
      :desc => "The fact name used to determine the node name used for all requests the agent
        makes to the master. WARNING: This setting is mutually exclusive with
        node_name_value.  Changing this setting also requires changes to the default
        auth.conf configuration on the Puppet Master.  Please see
        http://links.puppetlabs.com/node_name_fact for more information.",
      :hook => proc do |value|
        if !value.empty? and Puppet[:node_name_value] != Puppet[:certname]
          raise "Cannot specify both the node_name_value and node_name_fact settings"
        end
      end
    },
    :localconfig => { :default => "$statedir/localconfig",
      :owner => "root",
      :mode => 0660,
      :desc => "Where puppet agent caches the local configuration.  An
        extension indicating the cache format is added automatically."},
    :statefile => { :default => "$statedir/state.yaml",
      :mode => 0660,
      :desc => "Where puppet agent and puppet master store state associated
        with the running configuration.  In the case of puppet master,
        this file reflects the state discovered through interacting
        with clients."
      },
    :clientyamldir => {:default => "$vardir/client_yaml", :mode => "750", :desc => "The directory in which client-side YAML data is stored."},
    :client_datadir => {:default => "$vardir/client_data", :mode => "750", :desc => "The directory in which serialized data is stored on the client."},
    :classfile => { :default => "$statedir/classes.txt",
      :owner => "root",
      :mode => 0644,
      :desc => "The file in which puppet agent stores a list of the classes
        associated with the retrieved configuration.  Can be loaded in
        the separate `puppet` executable using the `--loadclasses`
        option."},
    :resourcefile => { :default => "$statedir/resources.txt",
      :owner => "root",
      :mode => 0644,
      :desc => "The file in which puppet agent stores a list of the resources
        associated with the retrieved configuration."  },
    :puppetdlog => { :default => "$logdir/puppetd.log",
      :owner => "root",
      :mode => 0640,
      :desc => "The log file for puppet agent.  This is generally not used."
    },
    :server => ["puppet", "The server to which server puppet agent should connect"],
    :ignoreschedules => [false,
      "Boolean; whether puppet agent should ignore schedules.  This is useful
      for initial puppet agent runs."],
    :puppetport => [8139, "Which port puppet agent listens on."],
    :noop => [false, "Whether puppet agent should be run in noop mode."],
    :runinterval => [1800, # 30 minutes
      "How often puppet agent applies the client configuration; in seconds.
      Note that a runinterval of 0 means \"run continuously\" rather than
      \"never run.\" If you want puppet agent to never run, you should start
      it with the `--no-client` option."],
    :listen => [false, "Whether puppet agent should listen for
      connections.  If this is true, then puppet agent will accept incoming
      REST API requests, subject to the default ACLs and the ACLs set in
      the `rest_authconfig` file. Puppet agent can respond usefully to
      requests on the `run`, `facts`, `certificate`, and `resource` endpoints."],
    :ca_server => ["$server", "The server to use for certificate
      authority requests.  It's a separate server because it cannot
      and does not need to horizontally scale."],
    :ca_port => ["$masterport", "The port to use for the certificate authority."],
    :catalog_format => {
      :default => "",
      :desc => "(Deprecated for 'preferred_serialization_format') What format to
        use to dump the catalog.  Only supports 'marshal' and 'yaml'.  Only
        matters on the client, since it asks the server for a specific format.",
      :hook => proc { |value|
        if value
          Puppet.warning "Setting 'catalog_format' is deprecated; use 'preferred_serialization_format' instead."
          Puppet.settings[:preferred_serialization_format] = value
        end
      }
    },
    :preferred_serialization_format => ["pson", "The preferred means of serializing
      ruby instances for passing over the wire.  This won't guarantee that all
      instances will be serialized using this method, since not all classes
      can be guaranteed to support this format, but it will be used for all
      classes that support it."],
    :puppetdlockfile => [ "$statedir/puppetdlock", "A lock file to temporarily stop puppet agent from doing anything."],
    :usecacheonfailure => [true,
      "Whether to use the cached configuration when the remote
      configuration will not compile.  This option is useful for testing
      new configurations, where you want to fix the broken configuration
      rather than reverting to a known-good one."
    ],
    :use_cached_catalog => [false,
      "Whether to only use the cached catalog rather than compiling a new catalog
      on every run.  Puppet can be run with this enabled by default and then selectively
      disabled when a recompile is desired."],
    :ignorecache => [false,
      "Ignore cache and always recompile the configuration.  This is
      useful for testing new configurations, where the local cache may in
      fact be stale even if the timestamps are up to date - if the facts
      change or if the server changes."
    ],
    :downcasefacts => [false, "Whether facts should be made all lowercase when sent to the server."],
    :dynamicfacts => ["memorysize,memoryfree,swapsize,swapfree",
      "Facts that are dynamic; these facts will be ignored when deciding whether
      changed facts should result in a recompile.  Multiple facts should be
      comma-separated."],
    :splaylimit => ["$runinterval",
      "The maximum time to delay before runs.  Defaults to being the same as the
      run interval."],
    :splay => [false,
      "Whether to sleep for a pseudo-random (but consistent) amount of time before
      a run."],
    :clientbucketdir => {
      :default => "$vardir/clientbucket",
      :mode => 0750,
      :desc => "Where FileBucket files are stored locally."
    },
    :configtimeout => [120,
      "How long the client should wait for the configuration to be retrieved
      before considering it a failure.  This can help reduce flapping if too
      many clients contact the server at one time."
    ],
    :reportserver => {
      :default => "$server",
      :call_on_define => false,
      :desc => "(Deprecated for 'report_server') The server to which to send transaction reports.",
      :hook => proc do |value|
        Puppet.settings[:report_server] = value if value
      end
    },
    :report_server => ["$server",
      "The server to send transaction reports to."
    ],
    :report_port => ["$masterport",
      "The port to communicate with the report_server."
    ],
    :inventory_server => ["$server",
      "The server to send facts to."
    ],
    :inventory_port => ["$masterport",
      "The port to communicate with the inventory_server."
    ],
    :report => [true,
      "Whether to send reports after every transaction."
    ],
    :lastrunfile =>  { :default => "$statedir/last_run_summary.yaml",
      :mode => 0644,
      :desc => "Where puppet agent stores the last run report summary in yaml format."
    },
    :lastrunreport =>  { :default => "$statedir/last_run_report.yaml",
      :mode => 0644,
      :desc => "Where puppet agent stores the last run report in yaml format."
    },
    :graph => [false, "Whether to create dot graph files for the different
      configuration graphs.  These dot files can be interpreted by tools
      like OmniGraffle or dot (which is part of ImageMagick)."],
    :graphdir => ["$statedir/graphs", "Where to store dot-outputted graphs."],
    :http_compression => [false, "Allow http compression in REST communication with the master.
      This setting might improve performance for agent -> master communications over slow WANs.
      Your puppet master needs to support compression (usually by activating some settings in a reverse-proxy
      in front of the puppet master, which rules out webrick).
      It is harmless to activate this settings if your master doesn't support
      compression, but if it supports it, this setting might reduce performance on high-speed LANs."]
  )

  setdefaults(:inspect,
      :archive_files => [false, "During an inspect run, whether to archive files whose contents are audited to a file bucket."],
      :archive_file_server => ["$server", "During an inspect run, the file bucket server to archive files to if archive_files is set."]
  )

  # Plugin information.

    setdefaults(
    :main,
    :plugindest => ["$libdir",
      "Where Puppet should store plugins that it pulls down from the central
      server."],
    :pluginsource => ["puppet://$server/plugins",
      "From where to retrieve plugins.  The standard Puppet `file` type
      is used for retrieval, so anything that is a valid file source can
      be used here."],
    :pluginsync => [false, "Whether plugins should be synced with the central server."],

    :pluginsignore => [".svn CVS .git", "What files to ignore when pulling down plugins."]
  )

  # Central fact information.

    setdefaults(
    :main,
    :factpath => {:default => "$vardir/lib/facter#{File::PATH_SEPARATOR}$vardir/facts",
      :desc => "Where Puppet should look for facts.  Multiple directories should
        be colon-separated, like normal PATH variables.",

      :call_on_define => true, # Call our hook with the default value, so we always get the value added to facter.
      :type => :setting, # Don't consider it a file, because it could be multiple colon-separated files
      :hook => proc { |value| Facter.search(value) if Facter.respond_to?(:search) }},
    :factdest => ["$vardir/facts/",
      "Where Puppet should store facts that it pulls down from the central
      server."],
    :factsource => ["puppet://$server/facts/",
      "From where to retrieve facts.  The standard Puppet `file` type
      is used for retrieval, so anything that is a valid file source can
      be used here."],
    :factsync => [false, "Whether facts should be synced with the central server."],
    :factsignore => [".svn CVS", "What files to ignore when pulling down facts."]
  )


    setdefaults(
    :tagmail,
    :tagmap => ["$confdir/tagmail.conf", "The mapping between reporting tags and email addresses."],
    :sendmail => [which('sendmail') || '', "Where to find the sendmail binary with which to send email."],

    :reportfrom => ["report@" + [Facter["hostname"].value, Facter["domain"].value].join("."), "The 'from' email address for the reports."],
    :smtpserver => ["none", "The server through which to send email reports."]
  )

    setdefaults(
    :rails,
    :dblocation => { :default => "$statedir/clientconfigs.sqlite3",
      :mode => 0660,
      :owner => "service",
      :group => "service",
      :desc => "The database cache for client configurations.  Used for
        querying within the language."
    },
    :dbadapter => [ "sqlite3", "The type of database to use." ],
    :dbmigrate => [ false, "Whether to automatically migrate the database." ],
    :dbname => [ "puppet", "The name of the database to use." ],
    :dbserver => [ "localhost", "The database server for caching. Only
      used when networked databases are used."],
    :dbport => [ "", "The database password for caching. Only
      used when networked databases are used."],
    :dbuser => [ "puppet", "The database user for caching. Only
      used when networked databases are used."],
    :dbpassword => [ "puppet", "The database password for caching. Only
      used when networked databases are used."],
    :dbconnections => [ '', "The number of database connections for networked
      databases.  Will be ignored unless the value is a positive integer."],
    :dbsocket => [ "", "The database socket location. Only used when networked
      databases are used.  Will be ignored if the value is an empty string."],
    :railslog => {:default => "$logdir/rails.log",
      :mode => 0600,
      :owner => "service",
      :group => "service",
      :desc => "Where Rails-specific logs are sent"
    },

    :rails_loglevel => ["info", "The log level for Rails connections.  The value must be
      a valid log level within Rails.  Production environments normally use `info`
      and other environments normally use `debug`."]
  )

    setdefaults(
    :couchdb,

    :couchdb_url => ["http://127.0.0.1:5984/puppet", "The url where the puppet couchdb database will be created"]
  )

    setdefaults(
    :transaction,
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

    setdefaults(
    :main,
    :external_nodes => ["none",

      "An external command that can produce node information.  The output
      must be a YAML dump of a hash, and that hash must have one or both of
      `classes` and `parameters`, where `classes` is an array and
      `parameters` is a hash.  For unknown nodes, the commands should
      exit with a non-zero exit code.

      This command makes it straightforward to store your node mapping
      information in other data sources like databases."])

        setdefaults(
        :ldap,
    :ldapnodes => [false,
      "Whether to search for node configurations in LDAP.  See
      http://projects.puppetlabs.com/projects/puppet/wiki/LDAP_Nodes for more information."],
    :ldapssl => [false,
      "Whether SSL should be used when searching for nodes.
      Defaults to false because SSL usually requires certificates
      to be set up on the client side."],
    :ldaptls => [false,
      "Whether TLS should be used when searching for nodes.
      Defaults to false because TLS usually requires certificates
      to be set up on the client side."],
    :ldapserver => ["ldap",
      "The LDAP server.  Only used if `ldapnodes` is enabled."],
    :ldapport => [389,
      "The LDAP port.  Only used if `ldapnodes` is enabled."],

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
    :ldappassword => ["", "The password to use to connect to LDAP."],
    :ldapbase => ["",
      "The search base for LDAP searches.  It's impossible to provide
      a meaningful default here, although the LDAP libraries might
      have one already set.  Generally, it should be the 'ou=Hosts'
      branch under your main directory."]
  )

  setdefaults(:master,
    :storeconfigs => {
      :default => false,
      :desc => "Whether to store each client's configuration, including catalogs, facts,
and related data.  This also enables the import and export of resources in
the Puppet language - a mechanism for exchange resources between nodes.

By default this uses ActiveRecord and an SQL database to store and query
the data; this, in turn, will depend on Rails being available.

You can adjust the backend using the storeconfigs_backend setting.",
      # Call our hook with the default value, so we always get the libdir set.
      :call_on_define => true,
      :hook => proc do |value|
        require 'puppet/node'
        require 'puppet/node/facts'
        if value
          Puppet.settings[:async_storeconfigs] or
            Puppet::Resource::Catalog.indirection.cache_class = :store_configs
          Puppet::Node::Facts.indirection.cache_class = :store_configs
          Puppet::Node.indirection.cache_class = :store_configs

          Puppet::Resource.indirection.terminus_class = :store_configs
        end
      end
    },
    :storeconfigs_backend => {
      :default => "active_record",
      :desc => "Configure the backend terminus used for StoreConfigs.
By default, this uses the ActiveRecord store, which directly talks to the
database from within the Puppet Master process."
    }
  )

  # This doesn't actually work right now.

    setdefaults(
    :parser,

    :lexical => [false, "Whether to use lexical scoping (vs. dynamic)."],
    :templatedir => ["$vardir/templates",
      "Where Puppet looks for template files.  Can be a list of colon-seperated
      directories."
    ]
  )
  setdefaults(
    :puppetdoc,
    :document_all => [false, "Document all resources"]
  )
end
