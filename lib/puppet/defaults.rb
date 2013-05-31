# The majority of Puppet's configuration settings are set in this file.


module Puppet

  def self.default_diffargs
    if (Facter.value(:kernel) == "AIX" && Facter.value(:kernelmajversion) == "5300")
      ""
    else
      "-u"
    end
  end

  ############################################################################################
  # NOTE: For information about the available values for the ":type" property of settings,
  #   see the docs for Settings.define_settings
  ############################################################################################

  AS_DURATION = %q{This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).}
  STORECONFIGS_ONLY = %q{This setting is only used by the ActiveRecord storeconfigs and inventory backends, which are deprecated.}

  define_settings(:main,
    :confdir  => {
        :default  => nil,
        :type     => :directory,
        :desc     =>
            "The main Puppet configuration directory.  The default for this setting is calculated based on the user.  If the process\n" +
            "is running as root or the user that Puppet is supposed to run as, it defaults to a system directory, but if it's running as any other user,\n" +
            "it defaults to being in the user's home directory.",
    },
    :vardir   => {
        :default  => nil,
        :type     => :directory,
        :desc     => "Where Puppet stores dynamic and growing data.  The default for this setting is calculated specially, like `confdir`_.",
    },

    ### NOTE: this setting is usually being set to a symbol value.  We don't officially have a
    ###     setting type for that yet, but we might want to consider creating one.
    :name     => {
        :default  => nil,
        :desc     => "The name of the application, if we are running as one.  The\n" +
            "default is essentially $0 without the path or `.rb`.",
    }
  )

  define_settings(:main,
    :logdir => {
        :default  => nil,
        :type     => :directory,
        :mode     => 0750,
        :owner    => "service",
        :group    => "service",
        :desc     => "The directory in which to store log files",
    }
  )

  define_settings(:main,
    :trace => {
        :default  => false,
        :type     => :boolean,
        :desc     => "Whether to print stack traces on some errors",
    },
    :profile => {
        :default  => false,
        :type     => :boolean,
        :desc     => "Whether to enable experimental performance profiling",
    },
    :autoflush => {
      :default => true,
      :type       => :boolean,
      :desc       => "Whether log files should always flush to disk.",
      :hook       => proc { |value| Log.autoflush = value }
    },
    :syslogfacility => {
        :default  => "daemon",
        :desc     => "What syslog facility to use when logging to\n" +
            "syslog.  Syslog has a fixed list of valid facilities, and you must\n" +
            "choose one of those; you cannot just make one up."
    },
    :statedir => {
        :default  => "$vardir/state",
        :type     => :directory,
        :mode     => 01755,
        :desc     => "The directory where Puppet state is stored.  Generally,
          this directory can be removed without causing harm (although it
          might result in spurious service restarts)."
    },
    :rundir => {
      :default  => nil,
      :type     => :directory,
      :mode     => 0755,
      :owner    => "service",
      :group    => "service",
      :desc     => "Where Puppet PID files are kept."
    },
    :genconfig => {
        :default  => false,
        :type     => :boolean,
        :desc     => "Whether to just print a configuration to stdout and exit.  Only makes\n" +
            "sense when used interactively.  Takes into account arguments specified\n" +
            "on the CLI.",
    },
    :genmanifest => {
        :default  => false,
        :type     => :boolean,
        :desc     => "Whether to just print a manifest to stdout and exit.  Only makes\n" +
            "sense when used interactively.  Takes into account arguments specified\n" +
            "on the CLI.",
    },
    :configprint => {
        :default  => "",
        :desc     => "Print the value of a specific configuration setting.  If the name of a\n" +
            "setting is provided for this, then the value is printed and puppet\n" +
            "exits.  Comma-separate multiple values.  For a list of all values,\n" +
            "specify 'all'.",
    },
    :color => {
      :default => "ansi",
      :type    => :string,
      :desc    => "Whether to use colors when logging to the console.  Valid values are\n" +
          "`ansi` (equivalent to `true`), `html`, and `false`, which produces no color.\n" +
          "Defaults to false on Windows, as its console does not support ansi colors.",
    },
    :mkusers => {
        :default  => false,
        :type     => :boolean,
        :desc     => "Whether to create the necessary user and group that puppet agent will run as.",
    },
    :manage_internal_file_permissions => {
        :default  => true,
        :type     => :boolean,
        :desc     => "Whether Puppet should manage the owner, group, and mode of files it uses internally",
    },
    :onetime => {
        :default  => false,
        :type     => :boolean,
        :desc     => "Run the configuration once, rather than as a long-running\n" +
          "daemon. This is useful for interactively running puppetd.",
        :short    => 'o',
    },
    :path => {
        :default          => "none",
        :desc             => "The shell search path.  Defaults to whatever is inherited\n" +
            "from the parent process.",
        :call_hook => :on_define_and_write,
        :hook             => proc do |value|
          ENV["PATH"] = "" if ENV["PATH"].nil?
          ENV["PATH"] = value unless value == "none"
          paths = ENV["PATH"].split(File::PATH_SEPARATOR)
          Puppet::Util::Platform.default_paths.each do |path|
            ENV["PATH"] += File::PATH_SEPARATOR + path unless paths.include?(path)
          end
          value
        end
    },
    :libdir => {
        :type           => :directory,
        :default        => "$vardir/lib",
        :desc           => "An extra search path for Puppet.  This is only useful\n" +
            "for those files that Puppet will load on demand, and is only\n" +
            "guaranteed to work for those cases.  In fact, the autoload\n" +
            "mechanism is responsible for making sure this directory\n" +
            "is in Ruby's search path\n",
      :call_hook => :on_initialize_and_write,
      :hook             => proc do |value|
        $LOAD_PATH.delete(@oldlibdir) if defined?(@oldlibdir) and $LOAD_PATH.include?(@oldlibdir)
        @oldlibdir = value
        $LOAD_PATH << value
      end
    },
    :ignoreimport => {
        :default  => false,
        :type     => :boolean,
        :desc     => "If true, allows the parser to continue without requiring\n" +
            "all files referenced with `import` statements to exist. This setting was primarily\n" +
            "designed for use with commit hooks for parse-checking.",
    },
    :environment => {
        :default  => "production",
        :desc     => "The environment Puppet is running in.  For clients\n" +
            "(e.g., `puppet agent`) this determines the environment itself, which\n" +
            "is used to find modules and much more.  For servers (i.e., `puppet master`)\n" +
            "this provides the default environment for nodes we know nothing about."
    },
    :diff_args => {
        :default  => default_diffargs,
        :desc     => "Which arguments to pass to the diff command when printing differences between\n" +
            "files. The command to use can be chosen with the `diff` setting.",
    },
    :diff => {
      :default => (Puppet.features.microsoft_windows? ? "" : "diff"),
      :desc    => "Which diff command to use when printing differences between files. This setting\n" +
        "has no default value on Windows, as standard `diff` is not available, but Puppet can use many\n" +
        "third-party diff tools.",
    },
    :show_diff => {
        :type     => :boolean,
        :default  => false,
        :desc     => "Whether to log and report a contextual diff when files are being replaced.  This causes\n" +
            "partial file contents to pass through Puppet's normal logging and reporting system, so this setting\n" +
            "should be used with caution if you are sending Puppet's reports to an insecure destination.\n" +
            "This feature currently requires the `diff/lcs` Ruby library.",
    },
    :daemonize => {
        :type     => :boolean,
        :default  => (Puppet.features.microsoft_windows? ? false : true),
        :desc     => "Whether to send the process into the background.  This defaults to true on POSIX systems,
          and to false on Windows (where Puppet currently cannot daemonize).",
        :short    => "D",
        :hook     => proc do |value|
          if value and Puppet.features.microsoft_windows?
            raise "Cannot daemonize on Windows"
          end
      end
    },
    :maximum_uid => {
        :default  => 4294967290,
        :desc     => "The maximum allowed UID.  Some platforms use negative UIDs\n" +
            "but then ship with tools that do not know how to handle signed ints, so the UIDs show up as\n" +
            "huge numbers that can then not be fed back into the system.  This is a hackish way to fail in a\n" +
            "slightly more useful way when that happens.",
    },
    :route_file => {
      :default    => "$confdir/routes.yaml",
      :desc       => "The YAML file containing indirector route configuration.",
    },
    :node_terminus => {
      :type       => :terminus,
      :default    => "plain",
      :desc       => "Where to find information about nodes.",
    },
    :node_cache_terminus => {
      :type       => :terminus,
      :default    => nil,
      :desc       => "How to store cached nodes.
      Valid values are (none), 'json', 'yaml' or write only yaml ('write_only_yaml').
      The master application defaults to 'write_only_yaml', all others to none.",
    },
    :data_binding_terminus => {
      :type    => :terminus,
      :default => "hiera",
      :desc    => "Where to retrive information about data.",
    },
    :hiera_config => {
      :default => "$confdir/hiera.yaml",
      :desc    => "The hiera configuration file. Puppet only reads this file on startup, so you must restart the puppet master every time you edit it.",
      :type    => :file,
    },
    :catalog_terminus => {
      :type       => :terminus,
      :default    => "compiler",
      :desc       => "Where to get node catalogs.  This is useful to change if, for instance,
      you'd like to pre-compile catalogs and store them in memcached or some other easily-accessed store.",
    },
    :catalog_cache_terminus => {
      :type       => :terminus,
      :default    => nil,
      :desc       => "How to store cached catalogs. Valid values are 'json' and 'yaml'. The agent application defaults to 'json'."
    },
    :facts_terminus => {
      :default => 'facter',
      :desc => "The node facts terminus.",
      :call_hook => :on_initialize_and_write,
      :hook => proc do |value|
        require 'puppet/node/facts'
        # Cache to YAML if we're uploading facts away
        if %w[rest inventory_service].include? value.to_s
          Puppet.info "configuring the YAML fact cache because a remote terminus is active"
          Puppet::Node::Facts.indirection.cache_class = :yaml
        end
      end
    },
    :inventory_terminus => {
      :type       => :terminus,
      :default    => "$facts_terminus",
      :desc       => "Should usually be the same as the facts terminus",
    },
    :default_file_terminus => {
      :type       => :terminus,
      :default    => "rest",
      :desc       => "The default source for files if no server is given in a
      uri, e.g. puppet:///file. The default of `rest` causes the file to be
      retrieved using the `server` setting. When running `apply` the default
      is `file_server`, causing requests to be filled locally."
    },
    :httplog => {
        :default  => "$logdir/http.log",
        :type     => :file,
        :owner    => "root",
        :mode     => 0640,
        :desc     => "Where the puppet agent web server logs.",
    },
    :http_proxy_host => {
      :default    => "none",
      :desc       => "The HTTP proxy host to use for outgoing connections.  Note: You
      may need to use a FQDN for the server hostname when using a proxy.",
    },
    :http_proxy_port => {
      :default    => 3128,
      :desc       => "The HTTP proxy port to use for outgoing connections",
    },
    :filetimeout => {
      :default    => "15s",
      :type       => :duration,
      :desc       => "The minimum time to wait between checking for updates in
      configuration files.  This timeout determines how quickly Puppet checks whether
      a file (such as manifests or templates) has changed on disk. #{AS_DURATION}",
    },
    :queue_type => {
      :default    => "stomp",
      :desc       => "Which type of queue to use for asynchronous processing.",
    },
    :queue_type => {
      :default    => "stomp",
      :desc       => "Which type of queue to use for asynchronous processing.",
    },
    :queue_source => {
      :default    => "stomp://localhost:61613/",
      :desc       => "Which type of queue to use for asynchronous processing.  If your stomp server requires
      authentication, you can include it in the URI as long as your stomp client library is at least 1.1.1",
    },
    :async_storeconfigs => {
        :default  => false,
        :type     => :boolean,
        :desc     => "Whether to use a queueing system to provide asynchronous database integration.
      Requires that `puppet queue` be running.",
        :hook     => proc do |value|
          if value
            # This reconfigures the terminii for Node, Facts, and Catalog
            Puppet.settings[:storeconfigs] = true

            # But then we modify the configuration
            Puppet::Resource::Catalog.indirection.cache_class = :queue
            Puppet.settings[:catalog_cache_terminus] = :queue
          else
            raise "Cannot disable asynchronous storeconfigs in a running process"
          end
        end
    },
    :thin_storeconfigs => {
      :default  => false,
      :type     => :boolean,
      :desc     =>
    "Boolean; whether Puppet should store only facts and exported resources in the storeconfigs
    database. This will improve the performance of exported resources with the older
    `active_record` backend, but will disable external tools that search the storeconfigs database.
    Thinning catalogs is generally unnecessary when using PuppetDB to store catalogs.",
      :hook     => proc do |value|
        Puppet.settings[:storeconfigs] = true if value
        end
      },
    :config_version => {
      :default    => "",
      :desc       => "How to determine the configuration version.  By default, it will be the
      time that the configuration is parsed, but you can provide a shell script to override how the
      version is determined.  The output of this script will be added to every log message in the
      reports, allowing you to correlate changes on your hosts to the source version on the server.",
    },
    :zlib => {
        :default  => true,
        :type     => :boolean,
        :desc     => "Boolean; whether to use the zlib library",
    },
    :prerun_command => {
      :default    => "",
      :desc       => "A command to run before every agent run.  If this command returns a non-zero
      return code, the entire Puppet run will fail.",
    },
    :postrun_command => {
      :default    => "",
      :desc       => "A command to run after every agent run.  If this command returns a non-zero
      return code, the entire Puppet run will be considered to have failed, even though it might have
      performed work during the normal run.",
    },
    :freeze_main => {
        :default  => false,
        :type     => :boolean,
        :desc     => "Freezes the 'main' class, disallowing any code to be added to it.  This\n" +
            "essentially means that you can't have any code outside of a node, class, or definition other\n" +
            "than in the site manifest.",
    },
    :stringify_facts => {
      :default => true,
      :type    => :boolean,
      :desc    => "Flatten fact values to strings using #to_s. Means you can't have arrays or hashes as fact values.",
    }
  )
  Puppet.define_settings(:module_tool,
    :module_repository  => {
      :default  => 'https://forge.puppetlabs.com',
      :desc     => "The module repository",
    },
    :module_working_dir => {
        :default  => '$vardir/puppet-module',
        :desc     => "The directory into which module tool data is stored",
    }
  )

    Puppet.define_settings(
    :main,

    # We have to downcase the fqdn, because the current ssl stuff (as oppsed to in master) doesn't have good facilities for
    # manipulating naming.
    :certname => {
      :default => Puppet::Settings.default_certname.downcase, :desc => "The name to use when handling certificates.  Defaults
      to the fully qualified domain name.",
      :call_hook => :on_define_and_write, # Call our hook with the default value, so we're always downcased
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
      :type   => :directory,
      :owner => "service",
      :desc => "The certificate directory."
    },
    :ssldir => {
      :default => "$confdir/ssl",
      :type   => :directory,
      :mode => 0771,
      :owner => "service",
      :desc => "Where SSL certificates are kept."
    },
    :publickeydir => {
      :default => "$ssldir/public_keys",
      :type   => :directory,
      :owner => "service",
      :desc => "The public key directory."
    },
    :requestdir => {
      :default => "$ssldir/certificate_requests",
      :type => :directory,
      :owner => "service",
      :desc => "Where host certificate requests are stored."
    },
    :privatekeydir => {
      :default => "$ssldir/private_keys",
      :type   => :directory,
      :mode => 0750,
      :owner => "service",
      :desc => "The private key directory."
    },
    :privatedir => {
      :default => "$ssldir/private",
      :type   => :directory,
      :mode => 0750,
      :owner => "service",
      :desc => "Where the client stores private certificate information."
    },
    :passfile => {
      :default => "$privatedir/password",
      :type   => :file,
      :mode => 0640,
      :owner => "service",
      :desc => "Where puppet agent stores the password for its private key.
        Generally unused."
    },
    :hostcsr => {
      :default => "$ssldir/csr_$certname.pem",
      :type   => :file,
      :mode => 0644,
      :owner => "service",
      :desc => "Where individual hosts store and look for their certificate requests."
    },
    :hostcert => {
      :default => "$certdir/$certname.pem",
      :type   => :file,
      :mode => 0644,
      :owner => "service",
      :desc => "Where individual hosts store and look for their certificates."
    },
    :hostprivkey => {
      :default => "$privatekeydir/$certname.pem",
      :type   => :file,
      :mode => 0600,
      :owner => "service",
      :desc => "Where individual hosts store and look for their private key."
    },
    :hostpubkey => {
      :default => "$publickeydir/$certname.pem",
      :type   => :file,
      :mode => 0644,
      :owner => "service",
      :desc => "Where individual hosts store and look for their public key."
    },
    :localcacert => {
      :default => "$certdir/ca.pem",
      :type   => :file,
      :mode => 0644,
      :owner => "service",
      :desc => "Where each client stores the CA certificate."
    },
    ## JJM - The ssl_client_ca_chain setting is commented out because it is
    # intended for (#3143) and is not expected to be used until CA chaining is
    # supported.
    # :ssl_client_ca_chain => {
    #   :type  => :file,
    #   :mode  => 0644,
    #   :owner => "service",
    #   :desc  => "The list of CA certificate to complete the chain of trust to CA certificates \n" <<
    #             "listed in the ssl_client_ca_auth file."
    # },
    :ssl_client_ca_auth => {
      :type  => :file,
      :mode  => 0644,
      :owner => "service",
      :desc  => "Certificate authorities who issue server certificates.  SSL servers will not be \n" <<
                "considered authentic unless they posses a certificate issued by an authority \n" <<
                "listed in this file.  If this setting has no value then the Puppet master's CA \n" <<
                "certificate (localcacert) will be used."
    },
    ## JJM - The ssl_server_ca_chain setting is commented out because it is
    # intended for (#3143) and is not expected to be used until CA chaining is
    # supported.
    # :ssl_server_ca_chain => {
    #   :type  => :file,
    #   :mode  => 0644,
    #   :owner => "service",
    #   :desc  => "The list of CA certificate to complete the chain of trust to CA certificates \n" <<
    #             "listed in the ssl_server_ca_auth file."
    # },
    :ssl_server_ca_auth => {
      :type  => :file,
      :mode  => 0644,
      :owner => "service",
      :desc  => "Certificate authorities who issue client certificates.  SSL clients will not be \n" <<
                "considered authentic unless they posses a certificate issued by an authority \n" <<
                "listed in this file.  If this setting has no value then the Puppet master's CA \n" <<
                "certificate (localcacert) will be used."
    },
    :hostcrl => {
      :default => "$ssldir/crl.pem",
      :type   => :file,
      :mode => 0644,
      :owner => "service",
      :desc => "Where the host's certificate revocation list can be found.
        This is distinct from the certificate authority's CRL."
    },
    :certificate_revocation => {
        :default  => true,
        :type     => :boolean,
        :desc     => "Whether certificate revocation should be supported by downloading a Certificate Revocation List (CRL)
            to all clients.  If enabled, CA chaining will almost definitely not work.",
    },
    :certificate_expire_warning => {
      :default  => "60d",
      :type     => :duration,
      :desc     => "The window of time leading up to a certificate's expiration that a notification
        will be logged. This applies to CA, master, and agent certificates. #{AS_DURATION}"
    }
  )

    define_settings(
    :ca,
    :ca_name => {
      :default    => "Puppet CA: $certname",
      :desc       => "The name to use the Certificate Authority certificate.",
    },
    :cadir => {
      :default => "$ssldir/ca",
      :type => :directory,
      :owner => "service",
      :group => "service",
      :mode => 0770,
      :desc => "The root directory for the certificate authority."
    },
    :cacert => {
      :default => "$cadir/ca_crt.pem",
      :type => :file,
      :owner => "service",
      :group => "service",
      :mode => 0660,
      :desc => "The CA certificate."
    },
    :cakey => {
      :default => "$cadir/ca_key.pem",
      :type => :file,
      :owner => "service",
      :group => "service",
      :mode => 0660,
      :desc => "The CA private key."
    },
    :capub => {
      :default => "$cadir/ca_pub.pem",
      :type => :file,
      :owner => "service",
      :group => "service",
      :desc => "The CA public key."
    },
    :cacrl => {
      :default => "$cadir/ca_crl.pem",
      :type => :file,
      :owner => "service",
      :group => "service",
      :mode => 0664,

      :desc => "The certificate revocation list (CRL) for the CA. Will be used if present but otherwise ignored.",
    },
    :caprivatedir => {
      :default => "$cadir/private",
      :type => :directory,
      :owner => "service",
      :group => "service",
      :mode => 0770,
      :desc => "Where the CA stores private certificate information."
    },
    :csrdir => {
      :default => "$cadir/requests",
      :type => :directory,
      :owner => "service",
      :group => "service",
      :desc => "Where the CA stores certificate requests"
    },
    :signeddir => {
      :default => "$cadir/signed",
      :type => :directory,
      :owner => "service",
      :group => "service",
      :mode => 0770,
      :desc => "Where the CA stores signed certificates."
    },
    :capass => {
      :default => "$caprivatedir/ca.pass",
      :type => :file,
      :owner => "service",
      :group => "service",
      :mode => 0660,
      :desc => "Where the CA stores the password for the private key"
    },
    :serial => {
      :default => "$cadir/serial",
      :type => :file,
      :owner => "service",
      :group => "service",
      :mode => 0644,
      :desc => "Where the serial number for certificates is stored."
    },
    :autosign => {
      :default => "$confdir/autosign.conf",
      :type => :file,
      :mode => 0644,
      :desc => "Whether to enable autosign.  Valid values are true (which
        autosigns any key request, and is a very bad idea), false (which
        never autosigns any key request), and the path to a file, which
        uses that configuration file to determine which keys to sign."},
    :allow_duplicate_certs => {
      :default    => false,
      :type       => :boolean,
      :desc       => "Whether to allow a new certificate
      request to overwrite an existing certificate.",
    },
    :ca_ttl => {
      :default    => "5y",
      :type       => :duration,
      :desc       => "The default TTL for new certificates. If this setting is set, ca_days is ignored.
      #{AS_DURATION}"
    },
    :req_bits => {
      :default    => 4096,
      :desc       => "The bit length of the certificates.",
    },
    :keylength => {
      :default    => 4096,
      :desc       => "The bit length of keys.",
    },
    :cert_inventory => {
      :default => "$cadir/inventory.txt",
      :type => :file,
      :mode => 0644,
      :owner => "service",
      :group => "service",
      :desc => "A Complete listing of all certificates"
    }
  )

  # Define the config default.

    define_settings(:application,
      :config_file_name => {
          :type     => :string,
          :default  => Puppet::Settings.default_config_file_name,
          :desc     => "The name of the puppet config file.",
      },
      :config => {
          :type => :file,
          :default  => "$confdir/${config_file_name}",
          :desc     => "The configuration file for the current puppet application",
      },
      :pidfile => {
          :type => :file,
          :default  => "$rundir/${run_mode}.pid",
          :desc     => "The file containing the PID of a running process.  " <<
                       "This file is intended to be used by service management " <<
                       "frameworks and monitoring systems to determine if a " <<
                       "puppet process is still in the process table.",
      },
      :bindaddress => {
        :default    => "0.0.0.0",
        :desc       => "The address a listening server should bind to.",
      }
  )

  define_settings(:master,
    :user => {
      :default    => "puppet",
      :desc       => "The user puppet master should run as.",
    },
    :group => {
      :default    => "puppet",
      :desc       => "The group puppet master should run as.",
    },
    :manifestdir => {
      :default    => "$confdir/manifests",
      :type       => :directory,
      :desc       => "Where puppet master looks for its manifests.",
    },
    :manifest => {
      :default    => "$manifestdir/site.pp",
      :type       => :file,
      :desc       => "The entry-point manifest for puppet master.",
    },
    :code => {
      :default    => "",
      :desc       => "Code to parse directly.  This is essentially only used
      by `puppet`, and should only be set if you're writing your own Puppet
      executable",
    },
    :masterlog => {
      :default => "$logdir/puppetmaster.log",
      :type => :file,
      :owner => "service",
      :group => "service",
      :mode => 0660,
      :desc => "Where puppet master logs.  This is generally not used,
        since syslog is the default log destination."
    },
    :masterhttplog => {
      :default => "$logdir/masterhttp.log",
      :type => :file,
      :owner => "service",
      :group => "service",
      :mode => 0660,
      :create => true,
      :desc => "Where the puppet master web server logs."
    },
    :masterport => {
      :default    => 8140,
      :desc       => "The port for puppet master traffic. For puppet master,
      this is the port to listen on; for puppet agent, this is the port
      to make requests on. Both applications use this setting to get the port.",
    },
    :node_name => {
      :default    => "cert",
      :desc       => "How the puppet master determines the client's identity
      and sets the 'hostname', 'fqdn' and 'domain' facts for use in the manifest,
      in particular for determining which 'node' statement applies to the client.
      Possible values are 'cert' (use the subject's CN in the client's
      certificate) and 'facter' (use the hostname that the client
      reported in its facts)",
    },
    :bucketdir => {
      :default => "$vardir/bucket",
      :type => :directory,
      :mode => 0750,
      :owner => "service",
      :group => "service",
      :desc => "Where FileBucket files are stored."
    },
    :rest_authconfig => {
      :default    => "$confdir/auth.conf",
      :type       => :file,
      :desc       => "The configuration file that defines the rights to the different
      rest indirections.  This can be used as a fine-grained
      authorization system for `puppet master`.",
    },
    :ca => {
      :default    => true,
      :type       => :boolean,
      :desc       => "Whether the master should function as a certificate authority.",
    },
    :modulepath => {
      :default => "$confdir/modules#{File::PATH_SEPARATOR}/usr/share/puppet/modules",
      :type => :path,
      :desc => "The search path for modules, as a list of directories separated by the system path separator character. " +
          "(The POSIX path separator is ':', and the Windows path separator is ';'.)",
    },
    :ssl_client_header => {
      :default    => "HTTP_X_CLIENT_DN",
      :desc       => "The header containing an authenticated client's SSL DN.
      This header must be set by the proxy to the authenticated client's SSL
      DN (e.g., `/CN=puppet.puppetlabs.com`).  Puppet will parse out the Common
      Name (CN) from the Distinguished Name (DN) and use the value of the CN
      field for authorization.

      Note that the name of the HTTP header gets munged by the web server
      common gateway inteface: an `HTTP_` prefix is added, dashes are converted
      to underscores, and all letters are uppercased.  Thus, to use the
      `X-Client-DN` header, this setting should be `HTTP_X_CLIENT_DN`.",
    },
    :ssl_client_verify_header => {
      :default    => "HTTP_X_CLIENT_VERIFY",
      :desc       => "The header containing the status message of the client
      verification. This header must be set by the proxy to 'SUCCESS' if the
      client successfully authenticated, and anything else otherwise.

      Note that the name of the HTTP header gets munged by the web server
      common gateway inteface: an `HTTP_` prefix is added, dashes are converted
      to underscores, and all letters are uppercased.  Thus, to use the
      `X-Client-Verify` header, this setting should be
      `HTTP_X_CLIENT_VERIFY`.",
    },
    # To make sure this directory is created before we try to use it on the server, we need
    # it to be in the server section (#1138).
    :yamldir => {
      :default => "$vardir/yaml",
      :type => :directory,
      :owner => "service",
      :group => "service",
      :mode => "750",
      :desc => "The directory in which YAML data is stored, usually in a subdirectory."},
    :server_datadir => {
      :default => "$vardir/server_data",
      :type => :directory,
      :owner => "service",
      :group => "service",
      :mode => "750",
      :desc => "The directory in which serialized data is stored, usually in a subdirectory."},
    :reports => {
      :default    => "store",
      :desc       => "The list of reports to generate.  All reports are looked for
        in `puppet/reports/name.rb`, and multiple report names should be
        comma-separated (whitespace is okay).",
    },
    :reportdir => {
      :default => "$vardir/reports",
      :type => :directory,
      :mode => 0750,
      :owner => "service",
      :group => "service",
      :desc => "The directory in which to store reports
        received from the client.  Each client gets a separate
        subdirectory."},
    :reporturl => {
      :default    => "http://localhost:3000/reports/upload",
      :desc       => "The URL used by the http reports processor to send reports",
    },
    :fileserverconfig => {
      :default    => "$confdir/fileserver.conf",
      :type       => :file,
      :desc       => "Where the fileserver configuration is stored.",
    },
    :strict_hostname_checking => {
      :default    => false,
      :desc       => "Whether to only search for the complete
            hostname as it is in the certificate when searching for node information
            in the catalogs.",
    }
  )

  define_settings(:metrics,
    :rrddir => {
      :type     => :directory,
      :default  => "$vardir/rrd",
      :mode     => 0750,
      :owner    => "service",
      :group    => "service",
      :desc     => "The directory where RRD database files are stored.
        Directories for each reporting host will be created under
        this directory."
    },
    :rrdinterval => {
      :default  => "$runinterval",
      :type     => :duration,
      :desc     => "How often RRD should expect data.
            This should match how often the hosts report back to the server. #{AS_DURATION}",
    }
  )

  define_settings(:device,
    :devicedir =>  {
        :default  => "$vardir/devices",
        :type     => :directory,
        :mode     => "750",
        :desc     => "The root directory of devices' $vardir",
    },
    :deviceconfig => {
        :default  => "$confdir/device.conf",
        :desc     => "Path to the device config file for puppet device",
    }
  )

  define_settings(:agent,
    :node_name_value => {
      :default => "$certname",
      :desc => "The explicit value used for the node name for all requests the agent
        makes to the master. WARNING: This setting is mutually exclusive with
        node_name_fact.  Changing this setting also requires changes to the default
        auth.conf configuration on the Puppet Master.  Please see
        http://links.puppetlabs.com/node_name_value for more information."
    },
    :node_name_fact => {
      :default => "",
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
    :localconfig => {
      :default => "$statedir/localconfig",
      :type => :file,
      :owner => "root",
      :mode => 0660,
      :desc => "Where puppet agent caches the local configuration.  An
        extension indicating the cache format is added automatically."},
    :statefile => {
      :default => "$statedir/state.yaml",
      :type => :file,
      :mode => 0660,
      :desc => "Where puppet agent and puppet master store state associated
        with the running configuration.  In the case of puppet master,
        this file reflects the state discovered through interacting
        with clients."
      },
    :clientyamldir => {
      :default => "$vardir/client_yaml",
      :type => :directory,
      :mode => "750",
      :desc => "The directory in which client-side YAML data is stored."
    },
    :client_datadir => {
      :default => "$vardir/client_data",
      :type => :directory,
      :mode => "750",
      :desc => "The directory in which serialized data is stored on the client."
    },
    :classfile => {
      :default => "$statedir/classes.txt",
      :type => :file,
      :owner => "root",
      :mode => 0640,
      :desc => "The file in which puppet agent stores a list of the classes
        associated with the retrieved configuration.  Can be loaded in
        the separate `puppet` executable using the `--loadclasses`
        option."},
    :resourcefile => {
      :default => "$statedir/resources.txt",
      :type => :file,
      :owner => "root",
      :mode => 0640,
      :desc => "The file in which puppet agent stores a list of the resources
        associated with the retrieved configuration."  },
    :puppetdlog => {
      :default => "$logdir/puppetd.log",
      :type => :file,
      :owner => "root",
      :mode => 0640,
      :desc => "The log file for puppet agent.  This is generally not used."
    },
    :server => {
      :default => "puppet",
      :desc => "The server to which the puppet agent should connect"
    },
    :use_srv_records => {
      :default    => false,
      :type       => :boolean,
      :desc       => "Whether the server will search for SRV records in DNS for the current domain.",
    },
    :srv_domain => {
      :default    => "#{Puppet::Settings.domain_fact}",
      :desc       => "The domain which will be queried to find the SRV records of servers to use.",
    },
    :ignoreschedules => {
      :default    => false,
      :type       => :boolean,
    :desc         => "Boolean; whether puppet agent should ignore schedules.  This is useful
      for initial puppet agent runs.",
    },
    :puppetport => {
      :default    => 8139,
      :desc       => "Which port puppet agent listens on.",
    },
    :noop => {
      :default    => false,
      :type       => :boolean,
      :desc       => "Whether puppet agent should be run in noop mode.",
    },
    :runinterval => {
      :default  => "30m",
      :type     => :duration,
      :desc     => "How often puppet agent applies the catalog.
          Note that a runinterval of 0 means \"run continuously\" rather than
          \"never run.\" If you want puppet agent to never run, you should start
          it with the `--no-client` option. #{AS_DURATION}",
    },
    :listen => {
      :default    => false,
      :type       => :boolean,
      :desc       => "Whether puppet agent should listen for
      connections.  If this is true, then puppet agent will accept incoming
      REST API requests, subject to the default ACLs and the ACLs set in
      the `rest_authconfig` file. Puppet agent can respond usefully to
      requests on the `run`, `facts`, `certificate`, and `resource` endpoints.",
    },
    :ca_server => {
      :default    => "$server",
      :desc       => "The server to use for certificate
      authority requests.  It's a separate server because it cannot
      and does not need to horizontally scale.",
    },
    :ca_port => {
      :default    => "$masterport",
      :desc       => "The port to use for the certificate authority.",
    },
    :catalog_format => {
      :default => "",
      :desc => "(Deprecated for 'preferred_serialization_format') What format to
        use to dump the catalog.  Only supports 'marshal' and 'yaml'.  Only
        matters on the client, since it asks the server for a specific format.",
      :hook => proc { |value|
        if value
          Puppet.deprecation_warning "Setting 'catalog_format' is deprecated; use 'preferred_serialization_format' instead."
          Puppet.settings[:preferred_serialization_format] = value
        end
      }
    },
    :preferred_serialization_format => {
      :default    => "pson",
      :desc       => "The preferred means of serializing
      ruby instances for passing over the wire.  This won't guarantee that all
      instances will be serialized using this method, since not all classes
      can be guaranteed to support this format, but it will be used for all
      classes that support it.",
    },
    :agent_catalog_run_lockfile => {
      :default    => "$statedir/agent_catalog_run.lock",
      :type       => :string, # (#2888) Ensure this file is not added to the settings catalog.
      :desc       => "A lock file to indicate that a puppet agent catalog run is currently in progress.  " +
                     "The file contains the pid of the process that holds the lock on the catalog run.",
    },
    :agent_disabled_lockfile => {
        :default    => "$statedir/agent_disabled.lock",
        :type         => :file,
        :desc       => "A lock file to indicate that puppet agent runs have been administratively disabled.  File contains a JSON object with state information.",
    },
    :usecacheonfailure => {
      :default    => true,
      :type       => :boolean,
      :desc       => "Whether to use the cached configuration when the remote
      configuration will not compile.  This option is useful for testing
      new configurations, where you want to fix the broken configuration
      rather than reverting to a known-good one.",
    },
    :use_cached_catalog => {
      :default    => false,
      :type       => :boolean,
      :desc       => "Whether to only use the cached catalog rather than compiling a new catalog
      on every run.  Puppet can be run with this enabled by default and then selectively
      disabled when a recompile is desired.",
    },
    :ignoremissingtypes => {
      :default    => false,
      :type       => :boolean,
      :desc       => "Skip searching for classes and definitions that were missing during a
      prior compilation. The list of missing objects is maintained per-environment and
      persists until the environment is cleared or the master is restarted.",
    },
    :ignorecache => {
      :default    => false,
      :type       => :boolean,
      :desc       => "Ignore cache and always recompile the configuration.  This is
      useful for testing new configurations, where the local cache may in
      fact be stale even if the timestamps are up to date - if the facts
      change or if the server changes.",
    },
    :dynamicfacts => {
      :default    => "memorysize,memoryfree,swapsize,swapfree",
      :desc       => "(Deprecated) Facts that are dynamic; these facts will be ignored when deciding whether
      changed facts should result in a recompile.  Multiple facts should be
      comma-separated.",
      :hook => proc { |value|
        if value
          Puppet.deprecation_warning "The dynamicfacts setting is deprecated and will be ignored."
        end
      }
    },
    :splaylimit => {
      :default    => "$runinterval",
      :type       => :duration,
      :desc       => "The maximum time to delay before runs.  Defaults to being the same as the
      run interval. #{AS_DURATION}",
    },
    :splay => {
      :default    => false,
      :type       => :boolean,
      :desc       => "Whether to sleep for a pseudo-random (but consistent) amount of time before
      a run.",
    },
    :clientbucketdir => {
      :default  => "$vardir/clientbucket",
      :type     => :directory,
      :mode     => 0750,
      :desc     => "Where FileBucket files are stored locally."
    },
    :configtimeout => {
      :default  => "2m",
      :type     => :duration,
      :desc     => "How long the client should wait for the configuration to be retrieved
      before considering it a failure.  This can help reduce flapping if too
      many clients contact the server at one time. #{AS_DURATION}",
    },
    :report_server => {
      :default  => "$server",
      :desc     => "The server to send transaction reports to.",
    },
    :report_port => {
      :default  => "$masterport",
      :desc     => "The port to communicate with the report_server.",
    },
    :inventory_server => {
      :default  => "$server",
      :desc     => "The server to send facts to.",
    },
    :inventory_port => {
      :default  => "$masterport",
      :desc     => "The port to communicate with the inventory_server.",
    },
    :report => {
      :default  => true,
      :type     => :boolean,
      :desc     => "Whether to send reports after every transaction.",
    },
    :lastrunfile =>  {
      :default  => "$statedir/last_run_summary.yaml",
      :type     => :file,
      :mode     => 0644,
      :desc     => "Where puppet agent stores the last run report summary in yaml format."
    },
    :lastrunreport =>  {
      :default  => "$statedir/last_run_report.yaml",
      :type     => :file,
      :mode     => 0640,
      :desc     => "Where puppet agent stores the last run report in yaml format."
    },
    :graph => {
      :default  => false,
      :type     => :boolean,
      :desc     => "Whether to create dot graph files for the different
      configuration graphs.  These dot files can be interpreted by tools
      like OmniGraffle or dot (which is part of ImageMagick).",
    },
    :graphdir => {
      :default    => "$statedir/graphs",
      :type       => :directory,
      :desc       => "Where to store dot-outputted graphs.",
    },
    :http_compression => {
      :default    => false,
      :type       => :boolean,
      :desc       => "Allow http compression in REST communication with the master.
      This setting might improve performance for agent -> master communications over slow WANs.
      Your puppet master needs to support compression (usually by activating some settings in a reverse-proxy
      in front of the puppet master, which rules out webrick).
      It is harmless to activate this settings if your master doesn't support
      compression, but if it supports it, this setting might reduce performance on high-speed LANs.",
    },
    :waitforcert => {
      :default  => "2m",
      :type     => :duration,
      :desc     => "How frequently puppet agent should ask for a signed certificate.

      When starting for the first time, puppet agent will submit a certificate
      signing request (CSR) to the server named in the `ca_server` setting
      (usually the puppet master); this may be autosigned, or may need to be
      approved by a human, depending on the CA server's configuration.

      Puppet agent cannot apply configurations until its approved certificate is
      available. Since the certificate may or may not be available immediately,
      puppet agent will repeatedly try to fetch it at this interval. You can
      turn off waiting for certificates by specifying a time of 0, in which case
      puppet agent will exit if it cannot get a cert.
      #{AS_DURATION}",
    }
  )

  define_settings(:inspect,
    :archive_files => {
        :type     => :boolean,
        :default  => false,
        :desc     => "During an inspect run, whether to archive files whose contents are audited to a file bucket.",
    },
    :archive_file_server => {
        :default  => "$server",
        :desc     => "During an inspect run, the file bucket server to archive files to if archive_files is set.",
    }
  )

  # Plugin information.

  define_settings(
    :main,
    :plugindest => {
      :type       => :directory,
      :default    => "$libdir",
      :desc       => "Where Puppet should store plugins that it pulls down from the central
      server.",
    },
    :pluginsource => {
      :default    => "puppet://$server/plugins",
      :desc       => "From where to retrieve plugins.  The standard Puppet `file` type
      is used for retrieval, so anything that is a valid file source can
      be used here.",
    },
    :pluginsync => {
      :default    => true,
      :type       => :boolean,
      :desc       => "Whether plugins should be synced with the central server.",
    },

    :pluginsignore => {
        :default  => ".svn CVS .git",
        :desc     => "What files to ignore when pulling down plugins.",
    }
  )

  # Central fact information.

    define_settings(
    :main,
    :factpath => {
      :type     => :path,
      :default  => "$vardir/lib/facter#{File::PATH_SEPARATOR}$vardir/facts",
      :desc     => "Where Puppet should look for facts.  Multiple directories should
        be separated by the system path separator character. (The POSIX path separator is ':', and the Windows path separator is ';'.)",

      :call_hook => :on_initialize_and_write, # Call our hook with the default value, so we always get the value added to facter.
      :hook => proc { |value| Facter.search(value) if Facter.respond_to?(:search) }}
  )


    define_settings(
    :tagmail,
    :tagmap => {
      :default    => "$confdir/tagmail.conf",
      :desc       => "The mapping between reporting tags and email addresses.",
    },
    :sendmail => {
      :default    => which('sendmail') || '',
      :desc       => "Where to find the sendmail binary with which to send email.",
    },

    :reportfrom => {
        :default  => "report@" + [Facter["hostname"].value,Facter["domain"].value].join("."),
        :desc     => "The 'from' email address for the reports.",
    },

    :smtpserver => {
        :default  => "none",
        :desc     => "The server through which to send email reports.",
    },
    :smtpport => {
        :default  => 25,
        :desc     => "The TCP port through which to send email reports.",
    },
    :smtphelo => {
        :default  => Facter["fqdn"].value,
        :desc     => "The name by which we identify ourselves in SMTP HELO for reports.
          If you send to a smtpserver which does strict HELO checking (as with Postfix's
          `smtpd_helo_restrictions` access controls), you may need to ensure this resolves.",
    }
  )

    define_settings(
    :rails,
    :dblocation => {
      :default  => "$statedir/clientconfigs.sqlite3",
      :type     => :file,
      :mode     => 0660,
      :owner    => "service",
      :group    => "service",
      :desc     => "The sqlite database file. #{STORECONFIGS_ONLY}"
    },
    :dbadapter => {
      :default  => "sqlite3",
      :desc     => "The type of database to use. #{STORECONFIGS_ONLY}",
    },
    :dbmigrate => {
      :default  => false,
      :type     => :boolean,
      :desc     => "Whether to automatically migrate the database. #{STORECONFIGS_ONLY}",
    },
    :dbname => {
      :default  => "puppet",
      :desc     => "The name of the database to use. #{STORECONFIGS_ONLY}",
    },
    :dbserver => {
      :default  => "localhost",
      :desc     => "The database server for caching. Only
      used when networked databases are used.",
    },
    :dbport => {
      :default  => "",
      :desc     => "The database password for caching. Only
      used when networked databases are used. #{STORECONFIGS_ONLY}",
    },
    :dbuser => {
      :default  => "puppet",
      :desc     => "The database user for caching. Only
      used when networked databases are used. #{STORECONFIGS_ONLY}",
    },
    :dbpassword => {
      :default  => "puppet",
      :desc     => "The database password for caching. Only
      used when networked databases are used. #{STORECONFIGS_ONLY}",
    },
    :dbconnections => {
      :default  => '',
      :desc     => "The number of database connections for networked
      databases.  Will be ignored unless the value is a positive integer. #{STORECONFIGS_ONLY}",
    },
    :dbsocket => {
      :default  => "",
      :desc     => "The database socket location. Only used when networked
      databases are used.  Will be ignored if the value is an empty string. #{STORECONFIGS_ONLY}",
    },
    :railslog => {
      :default  => "$logdir/rails.log",
      :type     => :file,
      :mode     => 0600,
      :owner    => "service",
      :group    => "service",
      :desc     => "Where Rails-specific logs are sent. #{STORECONFIGS_ONLY}"
    },

    :rails_loglevel => {
        :default  => "info",
        :desc     => "The log level for Rails connections.  The value must be
            a valid log level within Rails.  Production environments normally use `info`
            and other environments normally use `debug`. #{STORECONFIGS_ONLY}",
    }
  )

    define_settings(
    :couchdb,

    :couchdb_url => {
        :default  => "http://127.0.0.1:5984/puppet",
        :desc     => "The url where the puppet couchdb database will be created.
        Only used when `facts_terminus` is set to `couch`.",
    }
  )

    define_settings(
    :transaction,
    :tags => {
      :default    => "",
      :desc       => "Tags to use to find resources.  If this is set, then
      only resources tagged with the specified tags will be applied.
      Values must be comma-separated.",
    },
    :evaltrace => {
      :default    => false,
      :type       => :boolean,
      :desc       => "Whether each resource should log when it is
      being evaluated.  This allows you to interactively see exactly
      what is being done.",
    },
    :summarize => {
        :default  => false,
        :type     => :boolean,
        :desc     => "Whether to print a transaction summary.",
    }
  )

    define_settings(
    :main,
    :external_nodes => {
        :default  => "none",
        :desc     => "An external command that can produce node information.  The command's output
            must be a YAML dump of a hash, and that hash must have a `classes` key and/or
            a `parameters` key, where `classes` is an array or hash and
            `parameters` is a hash.  For unknown nodes, the command should
            exit with a non-zero exit code.

            This command makes it straightforward to store your node mapping
            information in other data sources like databases.",
    }
    )

        define_settings(
        :ldap,
    :ldapssl => {
      :default  => false,
      :type   => :boolean,
      :desc   => "Whether SSL should be used when searching for nodes.
      Defaults to false because SSL usually requires certificates
      to be set up on the client side.",
    },
    :ldaptls => {
      :default  => false,
      :type     => :boolean,
      :desc     => "Whether TLS should be used when searching for nodes.
      Defaults to false because TLS usually requires certificates
      to be set up on the client side.",
    },
    :ldapserver => {
      :default  => "ldap",
      :desc     => "The LDAP server.  Only used if `node_terminus` is set to `ldap`.",
    },
    :ldapport => {
      :default  => 389,
      :desc     => "The LDAP port.  Only used if `node_terminus` is set to `ldap`.",
    },

    :ldapstring => {
      :default  => "(&(objectclass=puppetClient)(cn=%s))",
      :desc     => "The search string used to find an LDAP node.",
    },
    :ldapclassattrs => {
      :default  => "puppetclass",
      :desc     => "The LDAP attributes to use to define Puppet classes.  Values
      should be comma-separated.",
    },
    :ldapstackedattrs => {
      :default  => "puppetvar",
      :desc     => "The LDAP attributes that should be stacked to arrays by adding
      the values in all hierarchy elements of the tree.  Values
      should be comma-separated.",
    },
    :ldapattrs => {
      :default  => "all",
      :desc     => "The LDAP attributes to include when querying LDAP for nodes.  All
      returned attributes are set as variables in the top-level scope.
      Multiple values should be comma-separated.  The value 'all' returns
      all attributes.",
    },
    :ldapparentattr => {
      :default  => "parentnode",
      :desc     => "The attribute to use to define the parent node.",
    },
    :ldapuser => {
      :default  => "",
      :desc     => "The user to use to connect to LDAP.  Must be specified as a
      full DN.",
    },
    :ldappassword => {
      :default  => "",
      :desc     => "The password to use to connect to LDAP.",
    },
    :ldapbase => {
        :default  => "",
        :desc     => "The search base for LDAP searches.  It's impossible to provide
            a meaningful default here, although the LDAP libraries might
            have one already set.  Generally, it should be the 'ou=Hosts'
            branch under your main directory.",
    }
  )

  define_settings(:master,
    :storeconfigs => {
      :default  => false,
      :type     => :boolean,
      :desc     => "Whether to store each client's configuration, including catalogs, facts,
and related data.  This also enables the import and export of resources in
the Puppet language - a mechanism for exchange resources between nodes.

By default this uses ActiveRecord and an SQL database to store and query
the data; this, in turn, will depend on Rails being available.

You can adjust the backend using the storeconfigs_backend setting.",
      # Call our hook with the default value, so we always get the libdir set.
      :call_hook => :on_initialize_and_write,
      :hook => proc do |value|
        require 'puppet/node'
        require 'puppet/node/facts'
        if value
          if not Puppet.settings[:async_storeconfigs]
            Puppet::Resource::Catalog.indirection.cache_class = :store_configs
            Puppet.settings[:catalog_cache_terminus] = :store_configs
          end
          Puppet::Node::Facts.indirection.cache_class = :store_configs

          Puppet::Resource.indirection.terminus_class = :store_configs
        end
      end
    },
    :storeconfigs_backend => {
      :type => :terminus,
      :default => "active_record",
      :desc => "Configure the backend terminus used for StoreConfigs.
By default, this uses the ActiveRecord store, which directly talks to the
database from within the Puppet Master process."
    }
  )

  define_settings(:parser,
    :templatedir => {
        :default  => "$vardir/templates",
        :type     => :directory,
        :desc     => "Where Puppet looks for template files.  Can be a list of colon-separated
      directories.",
    },

    :allow_variables_with_dashes => {
      :default => false,
      :desc    => <<-'EOT'
Permit hyphens (`-`) in variable names and issue deprecation warnings about
them. This setting **should always be `false`;** setting it to `true`
will cause subtle and wide-ranging bugs. It will be removed in a future version.

Hyphenated variables caused major problems in the language, but were allowed
between Puppet 2.7.3 and 2.7.14. If you used them during this window, we
apologize for the inconvenience --- you can temporarily set this to `true`
in order to upgrade, and can rename your variables at your leisure. Please
revert it to `false` after you have renamed all affected variables.
EOT
    },
    :parser => {
      :default => "current",
      :desc => <<-'EOT'
Selects the parser to use for parsing puppet manifests (in puppet DSL language/'.pp' files).
Available choices are 'current' (the default), and 'future'.

The 'curent' parser means that the released version of the parser should be used.

The 'future' parser is a "time travel to the future" allowing early exposure to new language features.
What these fatures are will vary from release to release and they may be invididually configurable.

Available Since Puppet 3.2.
EOT
    },
   :max_errors => {
     :default => 10,
     :desc => <<-'EOT'
Sets the max number of logged/displayed parser validation errors in case multiple errors have been detected.
A value of 0 is the same as value 1. The count is per manifest.
EOT
   },
   :max_warnings => {
     :default => 10,
     :desc => <<-'EOT'
Sets the max number of logged/displayed parser validation warnings in case multiple errors have been detected.
A value of 0 is the same as value 1. The count is per manifest.
EOT
     },
  :max_deprecations => {
    :default => 10,
    :desc => <<-'EOT'
Sets the max number of logged/displayed parser validation deprecation warnings in case multiple errors have been detected.
A value of 0 is the same as value 1. The count is per manifest.
EOT
    }

  )
  define_settings(:puppetdoc,
    :document_all => {
        :default  => false,
        :type     => :boolean,
        :desc     => "Whether to document all resources when using `puppet doc` to
        generate manifest documentation.",
    }
  )
end
