---
layout: default
built_from_commit: 812d7420ea5d7e19e8003b26486a7c8847afdb25
title: Configuration Reference
toc: columns
canonical: "/puppet/latest/configuration.html"
---

# Configuration Reference

> **NOTE:** This page was generated from the Puppet source code on 2024-10-18 17:22:26 +0000



## Configuration settings

* Each of these settings can be specified in `puppet.conf` or on the
  command line.
* Puppet Enterprise (PE) and open source Puppet share the configuration settings
  documented here. However, PE defaults differ from open source defaults for some
  settings, such as `node_terminus`, `storeconfigs`, `always_retry_plugins`,
  `disable18n`, `environment_timeout` (when Code Manager is enabled), and the
  Puppet Server JRuby `max-active-instances` setting. To verify PE configuration
  defaults, check the `puppet.conf` or `pe-puppet-server.conf` file after
  installation.
* When using boolean settings on the command line, use `--setting` and
  `--no-setting` instead of `--setting (true|false)`. (Using `--setting false`
  results in "Error: Could not parse application options: needless argument".)
* Settings can be interpolated as `$variables` in other settings; `$environment`
  is special, in that puppet master will interpolate each agent node's
  environment instead of its own.
* Multiple values should be specified as comma-separated lists; multiple
  directories should be separated with the system path separator (usually
  a colon).
* Settings that represent time intervals should be specified in duration format:
  an integer immediately followed by one of the units 'y' (years of 365 days),
  'd' (days), 'h' (hours), 'm' (minutes), or 's' (seconds). The unit cannot be
  combined with other units, and defaults to seconds when omitted. Examples are
  '3600' which is equivalent to '1h' (one hour), and '1825d' which is equivalent
  to '5y' (5 years).
* If you use the `splay` setting, note that the period that it waits changes
  each time the Puppet agent is restarted.
* Settings that take a single file or directory can optionally set the owner,
  group, and mode for their value: `rundir = $vardir/run { owner = puppet,
  group = puppet, mode = 644 }`
* The Puppet executables ignores any setting that isn't relevant to
  their function.

See the [configuration guide][confguide] for more details.

[confguide]: https://puppet.com/docs/puppet/latest/config_about_settings.html


### agent_catalog_run_lockfile

A lock file to indicate that a puppet agent catalog run is currently in progress.
The file contains the pid of the process that holds the lock on the catalog run.

- *Default*: `$statedir/agent_catalog_run.lock`

### agent_disabled_lockfile

A lock file to indicate that puppet agent runs have been administratively
disabled.  File contains a JSON object with state information.

- *Default*: `$statedir/agent_disabled.lock`

### allow_duplicate_certs

Whether to allow a new certificate request to overwrite an existing
certificate request. If true, then the old certificate must be cleaned using
`puppetserver ca clean`, and the new request signed using `puppetserver ca sign`.

- *Default*: `false`

### allow_pson_serialization

Whether to allow PSON serialization. When unable to serialize to
JSON or other formats, Puppet falls back to PSON. This option affects the
configuration management service responses of Puppet Server and the process by
which the agent saves its cached catalog. With a default value of `false`, this
option is useful in preventing the loss of data because rich data cannot be
serialized via PSON.

- *Default*: `false`

### always_retry_plugins

Affects how we cache attempts to load Puppet resource types and features.  If
true, then calls to `Puppet.type.<type>?` `Puppet.feature.<feature>?`
will always attempt to load the type or feature (which can be an
expensive operation) unless it has already been loaded successfully.
This makes it possible for a single agent run to, e.g., install a
package that provides the underlying capabilities for a type or feature,
and then later load that type or feature during the same run (even if
the type or feature had been tested earlier and had not been available).

If this setting is set to false, then types and features will only be
checked once, and if they are not available, the negative result is
cached and returned for all subsequent attempts to load the type or
feature.  This behavior is almost always appropriate for the server,
and can result in a significant performance improvement for types and
features that are checked frequently.

- *Default*: `true`

### autoflush

Whether log files should always flush to disk.

- *Default*: `true`

### autosign

Whether (and how) to autosign certificate requests. This setting
is only relevant on a Puppet Server acting as a certificate authority (CA).

Valid values are true (autosigns all certificate requests; not recommended),
false (disables autosigning certificates), or the absolute path to a file.

The file specified in this setting may be either a **configuration file**
or a **custom policy executable.** Puppet will automatically determine
what it is: If the Puppet user (see the `user` setting) can execute the
file, it will be treated as a policy executable; otherwise, it will be
treated as a config file.

If a custom policy executable is configured, the CA Puppet Server will run it
every time it receives a CSR. The executable will be passed the subject CN of the
request _as a command line argument,_ and the contents of the CSR in PEM format
_on stdin._ It should exit with a status of 0 if the cert should be autosigned
and non-zero if the cert should not be autosigned.

If a certificate request is not autosigned, it will persist for review. An admin
user can use the `puppetserver ca sign` command to manually sign it, or can delete
the request.

For info on autosign configuration files, see
[the guide to Puppet's config files](https://puppet.com/docs/puppet/latest/config_file_autosign.html).

- *Default*: `$confdir/autosign.conf`

### basemodulepath

The search path for **global** modules. Should be specified as a
list of directories separated by the system path separator character. (The
POSIX path separator is ':', and the Windows path separator is ';'.)

These are the modules that will be used by _all_ environments. Note that
the `modules` directory of the active environment will have priority over
any global directories. For more info, see
<https://puppet.com/docs/puppet/latest/environments_about.html>

- *Default*: `$codedir/modules:/opt/puppetlabs/puppet/modules`

### binder_config

The binder configuration file. Puppet reads this file on each request to configure the bindings system.
If set to nil (the default), a $confdir/binder_config.yaml is optionally loaded. If it does not exists, a default configuration
is used. If the setting :binding_config is specified, it must reference a valid and existing yaml file.

- *Default*: ``

### bucketdir

Where FileBucket files are stored.

- *Default*: `$vardir/bucket`

### ca_fingerprint

The expected fingerprint of the CA certificate. If specified, the agent
will compare the CA certificate fingerprint that it downloads against this value
and reject the CA certificate if the values do not match. This only applies
during the first download of the CA certificate.

- *Default*: ``

### ca_name

The name to use the Certificate Authority certificate.

- *Default*: `Puppet CA: $certname`

### ca_port

The port to use for the certificate authority.

- *Default*: `$serverport`

### ca_refresh_interval

How often the Puppet agent refreshes its local CA
certificates. By default, CA certificates are refreshed every 24 hours. If a
different interval is specified, the agent refreshes its CA certificates during
the next agent run if the elapsed time since the certificates were last
refreshed exceeds the specified duration.

In general, the interval should be greater than the `runinterval`
value. Setting the `ca_refresh_interval` value to 0 or an equal or
lesser value than `runinterval` causes the CA certificates to be
refreshed on every run.

If the agent downloads new CA certs, the agent uses those for subsequent
network requests. If the refresh request fails or if the CA certs are
unchanged on the server, then the agent run will continue using the
local CA certs it already has. This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `1d`

### ca_server

The server to use for certificate
authority requests.  It's a separate server because it cannot
and does not need to horizontally scale.

- *Default*: `$server`

### ca_ttl

The default TTL for new certificates.
This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `5y`

### cacert

The CA certificate.

- *Default*: `$cadir/ca_crt.pem`

### cacrl

The certificate revocation list (CRL) for the CA.

- *Default*: `$cadir/ca_crl.pem`

### cadir

The root directory for the certificate authority.

- *Default*: `/etc/puppetlabs/puppetserver/ca`

### cakey

The CA private key.

- *Default*: `$cadir/ca_key.pem`

### capub

The CA public key.

- *Default*: `$cadir/ca_pub.pem`

### catalog_cache_terminus

How to store cached catalogs. Valid values are 'json', 'msgpack' and 'yaml'. The agent application defaults to 'json'.

- *Default*: ``

### catalog_terminus

Where to get node catalogs.  This is useful to change if, for instance,
you'd like to pre-compile catalogs and store them in memcached or some other easily-accessed store.

- *Default*: `compiler`

### cert_inventory

The inventory file. This is a text file to which the CA writes a
complete listing of all certificates.

- *Default*: `$cadir/inventory.txt`

### certdir

The certificate directory.

- *Default*: `$ssldir/certs`

### certificate_revocation

Whether certificate revocation checking should be enabled, and what level of
checking should be performed.

When certificate revocation is enabled, Puppet expects the contents of its CRL
to be one or more PEM-encoded CRLs concatenated together. When using a cert
bundle, CRLs for all CAs in the chain of trust must be included in the crl file.
The chain should be ordered from least to most authoritative, with the first CRL
listed being for the root of the chain and the last being for the leaf CA.

When certificate_revocation is set to 'true' or 'chain', Puppet ensures
that each CA in the chain of trust has not been revoked by its issuing CA.

When certificate_revocation is set to 'leaf', Puppet verifies certs against
the issuing CA's revocation list, but it does not verify the revocation status
of the issuing CA or any CA above it within the chain of trust.

When certificate_revocation is set to 'false', Puppet disables all
certificate revocation checking and does not attempt to download the CRL.

- *Default*: `chain`

### certname

The name to use when handling certificates. When a node
requests a certificate from the CA Puppet Server, it uses the value of the
`certname` setting as its requested Subject CN.

This is the name used when managing a node's permissions in
Puppet Server's [auth.conf](https://puppet.com/docs/puppetserver/latest/config_file_auth.html).
In most cases, it is also used as the node's name when matching
[node definitions](https://puppet.com/docs/puppet/latest/lang_node_definitions.html)
and requesting data from an ENC. (This can be changed with the `node_name_value`
and `node_name_fact` settings, although you should only do so if you have
a compelling reason.)

A node's certname is available in Puppet manifests as `$trusted['certname']`. (See
[Facts and Built-In Variables](https://puppet.com/docs/puppet/latest/lang_facts_and_builtin_vars.html)
for more details.)

* For best compatibility, you should limit the value of `certname` to
  only use lowercase letters, numbers, periods, underscores, and dashes. (That is,
  it should match `/A[a-z0-9._-]+Z/`.)
* The special value `ca` is reserved, and can't be used as the certname
  for a normal node.

  **Note:** You must set the certname in the main section of the puppet.conf file. Setting it in a different section causes errors.

Defaults to the node's fully qualified domain name.

- *Default*: `the Host's fully qualified domain name, as determined by Facter`

### ciphers

The list of ciphersuites for TLS connections initiated by puppet. The
default value is chosen to support TLS 1.0 and up, but can be made
more restrictive if needed. The ciphersuites must be specified in OpenSSL
format, not IANA.

- *Default*: `ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256`

### classfile

The file in which puppet agent stores a list of the classes
associated with the retrieved configuration.  Can be loaded in
the separate `puppet` executable using the `--loadclasses`
option.

- *Default*: `$statedir/classes.txt`

### client_datadir

The directory in which serialized data is stored on the client.

- *Default*: `$vardir/client_data`

### clientbucketdir

Where FileBucket files are stored locally.

- *Default*: `$vardir/clientbucket`

### clientyamldir

The directory in which client-side YAML data is stored.

- *Default*: `$vardir/client_yaml`

### code

Code to parse directly.  This is essentially only used
by `puppet`, and should only be set if you're writing your own Puppet
executable.


### codedir

The main Puppet code directory.  The default for this setting
is calculated based on the user.  If the process is running as root or
the user that Puppet is supposed to run as, it defaults to a system
directory, but if it's running as any other user, it defaults to being
in the user's home directory.

- *Default*: `Unix/Linux: /etc/puppetlabs/code -- Windows: C:\ProgramData\PuppetLabs\code -- Non-root user: ~/.puppetlabs/etc/code`

### color

Whether to use colors when logging to the console.  Valid values are
`ansi` (equivalent to `true`), `html`, and `false`, which produces no color.

- *Default*: `ansi`

### confdir

The main Puppet configuration directory.  The default for this setting
is calculated based on the user.  If the process is running as root or
the user that Puppet is supposed to run as, it defaults to a system
directory, but if it's running as any other user, it defaults to being
in the user's home directory.

- *Default*: `Unix/Linux: /etc/puppetlabs/puppet -- Windows: C:\ProgramData\PuppetLabs\puppet\etc -- Non-root user: ~/.puppetlabs/etc/puppet`

### config

The configuration file for the current puppet application.

- *Default*: `$confdir/${config_file_name}`

### config_file_name

The name of the puppet config file.

- *Default*: `puppet.conf`

### config_version

How to determine the configuration version.  By default, it will be the
time that the configuration is parsed, but you can provide a shell script to override how the
version is determined.  The output of this script will be added to every log message in the
reports, allowing you to correlate changes on your hosts to the source version on the server.

Setting a global value for config_version in puppet.conf is not allowed
(but it can be overridden from the commandline). Please set a
per-environment value in environment.conf instead. For more info, see
<https://puppet.com/docs/puppet/latest/environments_about.html>


### configprint

Prints the value of a specific configuration setting.  If the name of a
setting is provided for this, then the value is printed and puppet
exits.  Comma-separate multiple values.  For a list of all values,
specify 'all'. This setting is deprecated, the 'puppet config' command replaces this functionality.


### crl_refresh_interval

How often the Puppet agent refreshes its local Certificate
Revocation List (CRL). By default, the CRL is refreshed every 24 hours. If
a different interval is specified, the agent refreshes its CRL on the next
Puppet agent run if the elapsed time since the CRL was last refreshed
exceeds the specified interval.

In general, the interval should be greater than the `runinterval` value.
Setting the `crl_refresh_interval` value to 0 or an equal or lesser value
than `runinterval` causes the CRL to be refreshed on every run.

If the agent downloads a new CRL, the agent will use it for subsequent
network requests. If the refresh request fails or if the CRL is
unchanged on the server, then the agent run will continue using the
local CRL it already has.This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `1d`

### csr_attributes

An optional file containing custom attributes to add to certificate signing
requests (CSRs). You should ensure that this file does not exist on your CA
Puppet Server; if it does, unwanted certificate extensions may leak into
certificates created with the `puppetserver ca generate` command.

If present, this file must be a YAML hash containing a `custom_attributes` key
and/or an `extension_requests` key. The value of each key must be a hash, where
each key is a valid OID and each value is an object that can be cast to a string.

Custom attributes can be used by the CA when deciding whether to sign the
certificate, but are then discarded. Attribute OIDs can be any OID value except
the standard CSR attributes (i.e. attributes described in RFC 2985 section 5.4).
This is useful for embedding a pre-shared key for autosigning policy executables
(see the `autosign` setting), often by using the `1.2.840.113549.1.9.7`
("challenge password") OID.

Extension requests will be permanently embedded in the final certificate.
Extension OIDs must be in the "ppRegCertExt" (`1.3.6.1.4.1.34380.1.1`),
"ppPrivCertExt" (`1.3.6.1.4.1.34380.1.2`), or
"ppAuthCertExt" (`1.3.6.1.4.1.34380.1.3`) OID arcs. The ppRegCertExt arc is
reserved for four of the most common pieces of data to embed: `pp_uuid` (`.1`),
`pp_instance_id` (`.2`), `pp_image_name` (`.3`), and `pp_preshared_key` (`.4`)
--- in the YAML file, these can be referred to by their short descriptive names
instead of their full OID. The ppPrivCertExt arc is unregulated, and can be used
for site-specific extensions. The ppAuthCert arc is reserved for two pieces of
data to embed: `pp_authorization` (`.1`) and `pp_auth_role` (`.13`). As with
ppRegCertExt, in the YAML file, these can be referred to by their short
descriptive name instead of their full OID.

- *Default*: `$confdir/csr_attributes.yaml`

### csrdir

Where the CA stores certificate requests.

- *Default*: `$cadir/requests`

### daemonize

Whether to send the process into the background.  This defaults
to true on POSIX systems, and to false on Windows (where Puppet
currently cannot daemonize).

- *Default*: `true`

### data_binding_terminus

This setting has been deprecated. Use of any value other than 'hiera' should instead be configured
in a version 5 hiera.yaml. Until this setting is removed, it controls which data binding terminus
to use for global automatic data binding (across all environments). By default this value is 'hiera'.
A value of 'none' turns off the global binding.

- *Default*: `hiera`

### default_file_terminus

The default source for files if no server is given in a
uri, e.g. puppet:///file. The default of `rest` causes the file to be
retrieved using the `server` setting. When running `apply` the default
is `file_server`, causing requests to be filled locally.

- *Default*: `rest`

### default_manifest

The default main manifest for directory environments. Any environment that
doesn't set the `manifest` setting in its `environment.conf` file will use
this manifest.

This setting's value can be an absolute or relative path. An absolute path
will make all environments default to the same main manifest; a relative
path will allow each environment to use its own manifest, and Puppet will
resolve the path relative to each environment's main directory.

In either case, the path can point to a single file or to a directory of
manifests to be evaluated in alphabetical order.

- *Default*: `./manifests`

### default_schedules

Boolean; whether to generate the default schedule resources. Setting this to
false is useful for keeping external report processors clean of skipped schedule resources.

- *Default*: `true`

### deviceconfdir

The root directory of devices' $confdir.

- *Default*: `$confdir/devices`

### deviceconfig

Path to the device config file for puppet device.

- *Default*: `$confdir/device.conf`

### devicedir

The root directory of devices' $vardir.

- *Default*: `$vardir/devices`

### diff

Which diff command to use when printing differences between files. This setting
has no default value on Windows, as standard `diff` is not available, but Puppet can use many
third-party diff tools.

- *Default*: `diff`

### diff_args

Which arguments to pass to the diff command when printing differences between
files. The command to use can be chosen with the `diff` setting.

- *Default*: `-u`

### digest_algorithm

Which digest algorithm to use for file resources and the filebucket.
Valid values are sha256, sha384, sha512, sha224, md5. Default is
sha256.

- *Default*: `sha256`

### disable_i18n

If true, turns off all translations of Puppet and module
log messages, which affects error, warning, and info log messages,
as well as any translations in the report and CLI.

- *Default*: `true`

### disable_per_environment_manifest

Whether to disallow an environment-specific main manifest. When set
to `true`, Puppet will use the manifest specified in the `default_manifest` setting
for all environments. If an environment specifies a different main manifest in its
`environment.conf` file, catalog requests for that environment will fail with an error.

This setting requires `default_manifest` to be set to an absolute path.

- *Default*: `false`

### disable_warnings

A comma-separated list of warning types to suppress. If large numbers
of warnings are making Puppet's logs too large or difficult to use, you
can temporarily silence them with this setting.

If you are preparing to upgrade Puppet to a new major version, you
should re-enable all warnings for a while.

Valid values for this setting are:

* `deprecations` --- disables deprecation warnings.
* `undefined_variables` --- disables warnings about non existing variables.
* `undefined_resources` --- disables warnings about non existing resources.

- *Default*: `[]`

### dns_alt_names

A comma-separated list of alternate DNS names for Puppet Server. These are extra
hostnames (in addition to its `certname`) that the server is allowed to use when
serving agents. Puppet checks this setting when automatically creating a
certificate for Puppet agent or Puppet Server. These can be either IP or DNS, and the type
should be specified and followed with a colon. Untyped inputs will default to DNS.

In order to handle agent requests at a given hostname (like
"puppet.example.com"), Puppet Server needs a certificate that proves it's
allowed to use that name; if a server shows a certificate that doesn't include
its hostname, Puppet agents will refuse to trust it. If you use a single
hostname for Puppet traffic but load-balance it to multiple Puppet Servers, each
of those servers needs to include the official hostname in its list of extra
names.

**Note:** The list of alternate names is locked in when the server's
certificate is signed. If you need to change the list later, you can't just
change this setting; you also need to regenerate the certificate. For more
information on that process, see the
[cert regen docs](https://puppet.com/docs/puppet/latest/ssl_regenerate_certificates.html).

To see all the alternate names your servers are using, log into your CA server
and run `puppetserver ca list --all`, then check the output for `(alt names: ...)`.
Most agent nodes should NOT have alternate names; the only certs that should
have them are Puppet Server nodes that you want other agents to trust.


### document_all

Whether to document all resources when using `puppet doc` to
generate manifest documentation.

- *Default*: `false`

### environment

The environment in which Puppet is running. For clients,
such as `puppet agent`, this determines the environment itself, which
Puppet uses to find modules and much more. For servers, such as `puppet server`,
this provides the default environment for nodes that Puppet knows nothing about.

When defining an environment in the `[agent]` section, this refers to the
environment that the agent requests from the primary server. The environment doesn't
have to exist on the local filesystem because the agent fetches it from the
primary server. This definition is used when running `puppet agent`.

When defined in the `[user]` section, the environment refers to the path that
Puppet uses to search for code and modules related to its execution. This
requires the environment to exist locally on the filesystem where puppet is
being executed. Puppet subcommands, including `puppet module` and
`puppet apply`, use this definition.

Given that the context and effects vary depending on the
[config section](https://puppet.com/docs/puppet/latest/config_file_main.html#config-sections)
in which the `environment` setting is defined, do not set it globally.

- *Default*: `production`

### environment_data_provider

The name of a registered environment data provider used when obtaining environment
specific data. The three built in and registered providers are 'none' (no data), 'function' (data
obtained by calling the function 'environment::data()') and 'hiera' (data obtained using a data
provider configured using a hiera.yaml file in root of the environment).
Other environment data providers may be registered in modules on the module path. For such
custom data providers see the respective module documentation. This setting is deprecated.

- *Default*: ``

### environment_timeout

How long the Puppet server should cache data it loads from an
environment.

A value of `0` will disable caching. This setting can also be set to
`unlimited`, which will cache environments until the server is restarted
or told to refresh the cache. All other values will result in Puppet
server evicting environments that haven't been used within the last
`environment_timeout` seconds.

You should change this setting once your Puppet deployment is doing
non-trivial work. We chose the default value of `0` because it lets new
users update their code without any extra steps, but it lowers the
performance of your Puppet server. We recommend either:

* Setting this to `unlimited` and explicitly refreshing your Puppet server
  as part of your code deployment process.

* Setting this to a number that will keep your most actively used
  environments cached, but allow testing environments to fall out of the
  cache and reduce memory usage. A value of 3 minutes (3m) is a reasonable
  value.

Once you set `environment_timeout` to a non-zero value, you need to tell
Puppet server to read new code from disk using the `environment-cache` API
endpoint after you deploy new code. See the docs for the Puppet Server
[administrative API](https://puppet.com/docs/puppetserver/latest/admin-api/v1/environment-cache.html).

- *Default*: `0`

### environmentpath

A search path for directory environments, as a list of directories
separated by the system path separator character. (The POSIX path separator
is ':', and the Windows path separator is ';'.)

This setting must have a value set to enable **directory environments.** The
recommended value is `$codedir/environments`. For more details, see
<https://puppet.com/docs/puppet/latest/environments_about.html>

- *Default*: `$codedir/environments`

### evaltrace

Whether each resource should log when it is
being evaluated.  This allows you to interactively see exactly
what is being done.

- *Default*: `false`

### exclude_unchanged_resources

Specifies how unchanged resources are listed in reports. When
set to `true`, resources that have had no changes after catalog application
will not have corresponding unchanged resource status updates listed in a
report.

- *Default*: `true`

### external_nodes

The external node classifier (ENC) script to use for node data.
Puppet combines this data with the main manifest to produce node catalogs.

To enable this setting, set the `node_terminus` setting to `exec`.

This setting's value must be the path to an executable command that
can produce node information. The command must:

* Take the name of a node as a command-line argument.

* Return a YAML hash with up to three keys:
  * `classes` --- A list of classes, as an array or hash.
  * `environment` --- A string.
  * `parameters` --- A list of top-scope variables to set, as a hash.

* For unknown nodes, exit with a non-zero exit code.

Generally, an ENC script makes requests to an external data source.

For more info, see [the ENC documentation](https://puppet.com/docs/puppet/latest/nodes_external.html).

- *Default*: `none`

### fact_name_length_soft_limit

The soft limit for the length of a fact name.

- *Default*: `2560`

### fact_value_length_soft_limit

The soft limit for the length of a fact value.

- *Default*: `4096`

### factpath

Where Puppet should look for facts.  Multiple directories should
be separated by the system path separator character. (The POSIX path
separator is ':', and the Windows path separator is ';'.)

- *Default*: `$vardir/lib/facter:$vardir/facts`

### facts_terminus

The node facts terminus.

- *Default*: `facter`

### fileserverconfig

Where the fileserver configuration is stored.

- *Default*: `$confdir/fileserver.conf`

### filetimeout

The minimum time to wait between checking for updates in
configuration files.  This timeout determines how quickly Puppet checks whether
a file (such as manifests or puppet.conf) has changed on disk. The default will
change in a future release to be 'unlimited', requiring a reload of the Puppet
service to pick up changes to its internal configuration. Currently we do not
accept a value of 'unlimited'. To reparse files within an environment in
Puppet Server please use the environment_cache endpoint

- *Default*: `15s`

### forge_authorization

The authorization key to connect to the Puppet Forge. Leave blank for unauthorized or license based connections

- *Default*: ``

### freeze_main

Freezes the 'main' class, disallowing any code to be added to it.  This
essentially means that you can't have any code outside of a node,
class, or definition other than in the site manifest.

- *Default*: `false`

### genconfig

When true, causes Puppet applications to print an example config file
to stdout and exit. The example will include descriptions of each
setting, and the current (or default) value of each setting,
incorporating any settings overridden on the CLI (with the exception
of `genconfig` itself). This setting only makes sense when specified
on the command line as `--genconfig`.

- *Default*: `false`

### genmanifest

Whether to just print a manifest to stdout and exit.  Only makes
sense when specified on the command line as `--genmanifest`.  Takes into account arguments specified
on the CLI.

- *Default*: `false`

### graph

Whether to create .dot graph files, which let you visualize the
dependency and containment relationships in Puppet's catalog. You
can load and view these files with tools like
[OmniGraffle](http://www.omnigroup.com/applications/omnigraffle/) (OS X)
or [graphviz](http://www.graphviz.org/) (multi-platform).

Graph files are created when _applying_ a catalog, so this setting
should be used on nodes running `puppet agent` or `puppet apply`.

The `graphdir` setting determines where Puppet will save graphs. Note
that we don't save graphs for historical runs; Puppet will replace the
previous .dot files with new ones every time it applies a catalog.

See your graphing software's documentation for details on opening .dot
files. If you're using GraphViz's `dot` command, you can do a quick PNG
render with `dot -Tpng <DOT FILE> -o <OUTPUT FILE>`.

- *Default*: `false`

### graphdir

Where to save .dot-format graphs (when the `graph` setting is enabled).

- *Default*: `$statedir/graphs`

### group

The group Puppet Server will run as. Used to ensure
the agent side processes (agent, apply, etc) create files and
directories readable by Puppet Server when necessary.

- *Default*: `puppet`

### hiera_config

The hiera configuration file. Puppet only reads this file on startup, so you must restart the puppet server every time you edit it.

- *Default*: `$confdir/hiera.yaml. However, for backwards compatibility, if a file exists at $codedir/hiera.yaml, Puppet uses that instead.`

### hostcert

Where individual hosts store and look for their certificates.

- *Default*: `$certdir/$certname.pem`

### hostcert_renewal_interval

How often the Puppet agent renews its client certificate. By
default, the client certificate is renewed 30 days before the certificate
expires. If a different interval is specified, the agent renews its client
certificate during the next agent run, assuming that the client certificate has
expired within the specified duration.

In general, the `hostcert_renewal_interval` value should be greater than the
`runinterval` value. Setting the `hostcert_renewal_interval` value to 0 disables
automatic renewal.

If the agent downloads a new certificate, the agent will use it
for subsequent network requests. If the refresh request fails, the agent run
continues to use its existing certificate. This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `30d`

### hostcrl

Where the host's certificate revocation list can be found.
This is distinct from the certificate authority's CRL.

- *Default*: `$ssldir/crl.pem`

### hostcsr

Where individual hosts store their certificate request (CSR)
while waiting for the CA to issue their certificate.

- *Default*: `$requestdir/$certname.pem`

### hostprivkey

Where individual hosts store and look for their private key.

- *Default*: `$privatekeydir/$certname.pem`

### hostpubkey

Where individual hosts store and look for their public key.

- *Default*: `$publickeydir/$certname.pem`

### http_connect_timeout

The maximum amount of time to wait when establishing an HTTP connection. The default
value is 2 minutes.
This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `2m`

### http_debug

Whether to write HTTP request and responses to stderr. This should never be used in a production environment.

- *Default*: `false`

### http_extra_headers

The list of extra headers that will be sent with http requests to the primary server.
The header definition consists of a name and a value separated by a colon.

- *Default*: `[]`

### http_keepalive_timeout

The maximum amount of time a persistent HTTP connection can remain idle in the connection pool, before it is closed.  This timeout should be shorter than the keepalive timeout used on the HTTP server, e.g. Apache KeepAliveTimeout directive.
This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `4s`

### http_proxy_host

The HTTP proxy host to use for outgoing connections. The proxy will be bypassed if
the server's hostname matches the NO_PROXY environment variable or `no_proxy` setting. Note: You
may need to use a FQDN for the server hostname when using a proxy. Environment variable
http_proxy or HTTP_PROXY will override this value.

- *Default*: `none`

### http_proxy_password

The password for the user of an authenticated HTTP proxy.
Requires the `http_proxy_user` setting.

Note that passwords must be valid when used as part of a URL. If a password
contains any characters with special meanings in URLs (as specified by RFC 3986
section 2.2), they must be URL-encoded. (For example, `#` would become `%23`.)

- *Default*: `none`

### http_proxy_port

The HTTP proxy port to use for outgoing connections

- *Default*: `3128`

### http_proxy_user

The user name for an authenticated HTTP proxy. Requires the `http_proxy_host` setting.

- *Default*: `none`

### http_read_timeout

The time to wait for data to be read from an HTTP connection. If nothing is
read after the elapsed interval then the connection will be closed. The default value is 10 minutes.
This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `10m`

### http_user_agent

The HTTP User-Agent string to send when making network requests.

- *Default*: `Puppet/<version> Ruby/<version> (<architecture>)`

### ignore_plugin_errors

Whether the puppet run should ignore errors during pluginsync. If the setting
is false and there are errors during pluginsync, then the agent will abort the run and
submit a report containing information about the failed run.

- *Default*: `false`

### ignoremissingtypes

Skip searching for classes and definitions that were missing during a
prior compilation. The list of missing objects is maintained per-environment and
persists until the environment is cleared or the primary server is restarted.

- *Default*: `false`

### ignoreschedules

Boolean; whether puppet agent should ignore schedules.  This is useful
for initial puppet agent runs.

- *Default*: `false`

### include_legacy_facts

Whether to include legacy facts when requesting a catalog. This
option can be set to `false` if all puppet manifests, hiera.yaml, and hiera
configuration layers no longer access legacy facts, such as `$osfamily`, and
instead access structured facts, such as `$facts['os']['family']`.

- *Default*: `false`

### key_type

The type of private key. Valid values are `rsa` and `ec`. Default is `rsa`.

- *Default*: `rsa`

### keylength

The bit length of keys.

- *Default*: `4096`

### lastrunfile

Where puppet agent stores the last run report summary in yaml format.

- *Default*: `$publicdir/last_run_summary.yaml`

### lastrunreport

Where Puppet Agent stores the last run report, by default, in yaml format.
The format of the report can be changed by setting the `cache` key of the `report` terminus
in the [routes.yaml](https://puppet.com/docs/puppet/latest/config_file_routes.html) file.
To avoid mismatches between content and file extension, this setting needs to be
manually updated to reflect the terminus changes.

- *Default*: `$statedir/last_run_report.yaml`

### ldapattrs

The LDAP attributes to include when querying LDAP for nodes.  All
returned attributes are set as variables in the top-level scope.
Multiple values should be comma-separated.  The value 'all' returns
all attributes.

- *Default*: `all`

### ldapbase

The search base for LDAP searches.  It's impossible to provide
a meaningful default here, although the LDAP libraries might
have one already set.  Generally, it should be the 'ou=Hosts'
branch under your main directory.


### ldapclassattrs

The LDAP attributes to use to define Puppet classes.  Values
should be comma-separated.

- *Default*: `puppetclass`

### ldapparentattr

The attribute to use to define the parent node.

- *Default*: `parentnode`

### ldappassword

The password to use to connect to LDAP.


### ldapport

The LDAP port.

- *Default*: `389`

### ldapserver

The LDAP server.

- *Default*: `ldap`

### ldapssl

Whether SSL should be used when searching for nodes.
Defaults to false because SSL usually requires certificates
to be set up on the client side.

- *Default*: `false`

### ldapstackedattrs

The LDAP attributes that should be stacked to arrays by adding
the values in all hierarchy elements of the tree.  Values
should be comma-separated.

- *Default*: `puppetvar`

### ldapstring

The search string used to find an LDAP node.

- *Default*: `(&(objectclass=puppetClient)(cn=%s))`

### ldaptls

Whether TLS should be used when searching for nodes.
Defaults to false because TLS usually requires certificates
to be set up on the client side.

- *Default*: `false`

### ldapuser

The user to use to connect to LDAP.  Must be specified as a
full DN.


### libdir

An extra search path for Puppet.  This is only useful
for those files that Puppet will load on demand, and is only
guaranteed to work for those cases.  In fact, the autoload
mechanism is responsible for making sure this directory
is in Ruby's search path

- *Default*: `$vardir/lib`

### localcacert

Where each client stores the CA certificate.

- *Default*: `$certdir/ca.pem`

### localedest

Where Puppet should store translation files that it pulls down from the central
server.

- *Default*: `$vardir/locales`

### localesource

From where to retrieve translation files.  The standard Puppet `file` type
is used for retrieval, so anything that is a valid file source can
be used here.

- *Default*: `puppet:///locales`

### location_trusted

This will allow sending the name + password and the cookie header to all hosts that puppet may redirect to.
This may or may not introduce a security breach if puppet redirects you to a site to which you'll send your authentication info and cookies.

- *Default*: `false`

### log_level

Default logging level for messages from Puppet. Allowed values are:

* debug
* info
* notice
* warning
* err
* alert
* emerg
* crit

- *Default*: `notice`

### logdest

Where to send log messages. Choose between 'syslog' (the POSIX syslog
service), 'eventlog' (the Windows Event Log), 'console', or the path to a log
file. Multiple destinations can be set using a comma separated list (eg: `/path/file1,console,/path/file2`)

- *Default*: ``

### logdir

The directory in which to store log files

- *Default*: `Unix/Linux: /var/log/puppetlabs/puppet -- Windows: C:\ProgramData\PuppetLabs\puppet\var\log -- Non-root user: ~/.puppetlabs/var/log`

### manage_internal_file_permissions

Whether Puppet should manage the owner, group, and mode of files it uses internally.
**Note**: For Windows agents, the default is `false` for versions 4.10.13 and greater, versions 5.5.6 and greater, and versions 6.0 and greater.

- *Default*: `true`

### manifest

The entry-point manifest for the primary server. This can be one file
or a directory of manifests to be evaluated in alphabetical order. Puppet manages
this path as a directory if one exists or if the path ends with a / or \.

Setting a global value for `manifest` in puppet.conf is not allowed
(but it can be overridden from the commandline). Please use
directory environments instead. If you need to use something other than the
environment's `manifests` directory as the main manifest, you can set
`manifest` in environment.conf. For more info, see
<https://puppet.com/docs/puppet/latest/environments_about.html>

- *Default*: ``

### masterport

The default port puppet subcommands use to communicate
with Puppet Server. (eg `puppet facts upload`, `puppet agent`). May be
overridden by more specific settings (see `ca_port`, `report_port`).

- *Default*: `8140`

### max_deprecations

Sets the max number of logged/displayed parser validation deprecation
warnings in case multiple deprecation warnings have been detected. A value of 0
blocks the logging of deprecation warnings.  The count is per manifest.

- *Default*: `10`

### max_errors

Sets the max number of logged/displayed parser validation errors in case
multiple errors have been detected. A value of 0 is the same as a value of 1; a
minimum of one error is always raised.  The count is per manifest.

- *Default*: `10`

### max_warnings

Sets the max number of logged/displayed parser validation warnings in
case multiple warnings have been detected. A value of 0 blocks logging of
warnings.  The count is per manifest.

- *Default*: `10`

### maximum_uid

The maximum allowed UID.  Some platforms use negative UIDs
but then ship with tools that do not know how to handle signed ints,
so the UIDs show up as huge numbers that can then not be fed back into
the system.  This is a hackish way to fail in a slightly more useful
way when that happens.

- *Default*: `4294967290`

### maxwaitforcert

The maximum amount of time the Puppet agent should wait for its
certificate request to be signed. A value of `unlimited` will cause puppet agent
to ask for a signed certificate indefinitely.
This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `unlimited`

### maxwaitforlock

The maximum amount of time the puppet agent should wait for an
already running puppet agent to finish before starting a new one. This is set by default to 1 minute.
A value of `unlimited` will cause puppet agent to wait indefinitely.
This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `1m`

### merge_dependency_warnings

Whether to merge class-level dependency failure warnings.

When a class has a failed dependency, every resource in the class
generates a notice level message about the dependency failure,
and a warning level message about skipping the resource.

If true, all messages caused by a class dependency failure are merged
into one message associated with the class.

- *Default*: `false`

### mkusers

Whether to create the necessary user and group that puppet agent will run as.

- *Default*: `false`

### module_groups

Extra module groups to request from the Puppet Forge. This is an internal setting, and users should never change it.

- *Default*: ``

### module_repository

The module repository

- *Default*: `https://forgeapi.puppet.com`

### module_working_dir

The directory into which module tool data is stored

- *Default*: `$vardir/puppet-module`

### modulepath

The search path for modules, as a list of directories separated by the system
path separator character. (The POSIX path separator is ':', and the
Windows path separator is ';'.)

Setting a global value for `modulepath` in puppet.conf is not allowed
(but it can be overridden from the commandline). Please use
directory environments instead. If you need to use something other than the
default modulepath of `<ACTIVE ENVIRONMENT'S MODULES DIR>:$basemodulepath`,
you can set `modulepath` in environment.conf. For more info, see
<https://puppet.com/docs/puppet/latest/environments_about.html>


### name

The name of the application, if we are running as one.  The
default is essentially $0 without the path or `.rb`.

- *Default*: ``

### named_curve

The short name for the EC curve used to generate the EC private key. Valid
values must be one of the curves in `OpenSSL::PKey::EC.builtin_curves`.
Default is `prime256v1`.

- *Default*: `prime256v1`

### no_proxy

List of host or domain names that should not go through `http_proxy_host`. Environment variable no_proxy or NO_PROXY will override this value. Names can be specified as an FQDN `host.example.com`, wildcard `*.example.com`, dotted domain `.example.com`, or suffix `example.com`.

- *Default*: `localhost, 127.0.0.1`

### node_cache_terminus

How to store cached nodes.
Valid values are (none), 'json', 'msgpack', or 'yaml'.

- *Default*: ``

### node_name_fact

The fact name used to determine the node name used for all requests the agent
makes to the primary server. WARNING: This setting is mutually exclusive with
node_name_value.  Changing this setting also requires changes to
Puppet Server's default [auth.conf](https://puppet.com/docs/puppetserver/latest/config_file_auth.html).


### node_name_value

The explicit value used for the node name for all requests the agent
makes to the primary server. WARNING: This setting is mutually exclusive with
node_name_fact.  Changing this setting also requires changes to
Puppet Server's default [auth.conf](https://puppet.com/docs/puppetserver/latest/config_file_auth.html).

- *Default*: `$certname`

### node_terminus

Which node data plugin to use when compiling node catalogs.

When Puppet compiles a catalog, it combines two primary sources of info: the main manifest,
and a node data plugin (often called a "node terminus," for historical reasons). Node data
plugins provide three things for a given node name:

1. A list of classes to add to that node's catalog (and, optionally, values for their
   parameters).
2. Which Puppet environment the node should use.
3. A list of additional top-scope variables to set.

The three main node data plugins are:

* `plain` --- Returns no data, so that the main manifest controls all node configuration.
* `exec` --- Uses an
  [external node classifier (ENC)](https://puppet.com/docs/puppet/latest/nodes_external.html),
  configured by the `external_nodes` setting. This lets you pull a list of Puppet classes
  from any external system, using a small glue script to perform the request and format the
  result as YAML.
* `classifier` (formerly `console`) --- Specific to Puppet Enterprise. Uses the PE console
  for node data."

- *Default*: `plain`

### noop

Whether to apply catalogs in noop mode, which allows Puppet to
partially simulate a normal run. This setting affects puppet agent and
puppet apply.

When running in noop mode, Puppet will check whether each resource is in sync,
like it does when running normally. However, if a resource attribute is not in
the desired state (as declared in the catalog), Puppet will take no
action, and will instead report the changes it _would_ have made. These
simulated changes will appear in the report sent to the primary Puppet server, or
be shown on the console if running puppet agent or puppet apply in the
foreground. The simulated changes will not send refresh events to any
subscribing or notified resources, although Puppet will log that a refresh
event _would_ have been sent.

**Important note:**
[The `noop` metaparameter](https://puppet.com/docs/puppet/latest/metaparameter.html#noop)
allows you to apply individual resources in noop mode, and will override
the global value of the `noop` setting. This means a resource with
`noop => false` _will_ be changed if necessary, even when running puppet
agent with `noop = true` or `--noop`. (Conversely, a resource with
`noop => true` will only be simulated, even when noop mode is globally disabled.)

- *Default*: `false`

### number_of_facts_soft_limit

The soft limit for the total number of fact values. This counts the
child elements of all facts (e.g. all items of an array or a hash), not just top
level facts.

- *Default*: `10240`

### onetime

Perform one configuration run and exit, rather than spawning a long-running
daemon. This is useful for interactively running puppet agent, or
running puppet agent from cron.

- *Default*: `false`

### passfile

Where puppet agent stores the password for its private key.
Generally unused.

- *Default*: `$privatedir/password`

### path

The shell search path.  Defaults to whatever is inherited
from the parent process.

This setting can only be set in the `[main]` section of puppet.conf; it cannot
be set in `[server]`, `[agent]`, or an environment config section.

- *Default*: `none`

### payload_soft_limit

The soft limit for the size of the payload.

- *Default*: `16777216`

### pidfile

The file containing the PID of a running process.
This file is intended to be used by service management frameworks
and monitoring systems to determine if a puppet process is still in
the process table.

- *Default*: `$rundir/${run_mode}.pid`

### plugindest

Where Puppet should store plugins that it pulls down from the central
server.

- *Default*: `$libdir`

### pluginfactdest

Where Puppet should store external facts that are being handled by pluginsync

- *Default*: `$vardir/facts.d`

### pluginfactsource

Where to retrieve external facts for pluginsync

- *Default*: `puppet:///pluginfacts`

### pluginsignore

What files to ignore when pulling down plugins.

- *Default*: `.svn CVS .git .hg`

### pluginsource

From where to retrieve plugins.  The standard Puppet `file` type
is used for retrieval, so anything that is a valid file source can
be used here.

- *Default*: `puppet:///plugins`

### pluginsync

Whether plugins should be synced with the central server. This setting is
deprecated.

- *Default*: `true`

### postrun_command

A command to run after every agent run.  If this command returns a non-zero
return code, the entire Puppet run will be considered to have failed, even though it might have
performed work during the normal run.


### preferred_serialization_format

The preferred means of serializing
ruby instances for passing over the wire.  This won't guarantee that all
instances will be serialized using this method, since not all classes
can be guaranteed to support this format, but it will be used for all
classes that support it.

- *Default*: `json`

### preprocess_deferred

Whether Puppet should call deferred functions before applying
the catalog. If set to `true`, all prerequisites required for the
deferred function must be satisfied before the Puppet run. If set to
`false`, deferred functions follow Puppet relationships and
ordering. In this way, Puppet can install the prerequisites required for a
deferred function and call the deferred function in the same run.

- *Default*: `false`

### prerun_command

A command to run before every agent run.  If this command returns a non-zero
return code, the entire Puppet run will fail.


### preview_outputdir

The directory where catalog previews per node are generated.

- *Default*: `$vardir/preview`

### priority

The scheduling priority of the process.  Valid values are 'high',
'normal', 'low', or 'idle', which are mapped to platform-specific
values.  The priority can also be specified as an integer value and
will be passed as is, e.g. -5.  Puppet must be running as a privileged
user in order to increase scheduling priority.

- *Default*: ``

### privatedir

Where the client stores private certificate information.

- *Default*: `$ssldir/private`

### privatekeydir

The private key directory.

- *Default*: `$ssldir/private_keys`

### profile

Whether to enable experimental performance profiling

- *Default*: `false`

### publicdir

Where Puppet stores public files.

- *Default*: `Unix/Linux: /opt/puppetlabs/puppet/public -- Windows: C:\ProgramData\PuppetLabs\puppet\public -- Non-root user: ~/.puppetlabs/opt/puppet/public`

### publickeydir

The public key directory.

- *Default*: `$ssldir/public_keys`

### puppet_trace

Whether to print the Puppet stack trace on some errors.
This is a noop if `trace` is also set.

- *Default*: `false`

### puppetdlog

The fallback log file. This is only used when the `--logdest` option
is not specified AND Puppet is running on an operating system where both
the POSIX syslog service and the Windows Event Log are unavailable. (Currently,
no supported operating systems match that description.)

Despite the name, both puppet agent and puppet server will use this file
as the fallback logging destination.

For control over logging destinations, see the `--logdest` command line
option in the manual pages for puppet server, puppet agent, and puppet
apply. You can see man pages by running `puppet <SUBCOMMAND> --help`,
or read them online at https://puppet.com/docs/puppet/latest/man/.

- *Default*: `$logdir/puppetd.log`

### report

Whether to send reports after every transaction.

- *Default*: `true`

### report_configured_environmentpath

Specifies how environment paths are reported. When the value of
`versioned_environment_dirs` is `true`, Puppet applies the readlink function to
the `environmentpath` setting when constructing the environment's modulepath. The
full readlinked path is referred to as the "resolved path," and the configured
path potentially containing symlinks is the "configured path." When reporting
where resources come from, users may choose between the configured and resolved
path.

When set to `false`, the resolved paths are reported instead of the configured paths.

- *Default*: `true`

### report_include_system_store

Whether the 'http' report processor should include the system
certificate store when submitting reports to HTTPS URLs. If false, then
the 'http' processor will only trust HTTPS report servers whose certificates
are issued by the puppet CA or one of its intermediate CAs. If true, the
processor will additionally trust CA certificates in the system's
certificate store.

- *Default*: `false`

### report_port

The port to communicate with the report_server.

- *Default*: `$serverport`

### report_server

The server to send transaction reports to.

- *Default*: `$server`

### reportdir

The directory in which to store reports. Each node gets
a separate subdirectory in this directory. This setting is only
used when the `store` report processor is enabled (see the
`reports` setting).

- *Default*: `$vardir/reports`

### reports

The list of report handlers to use. When using multiple report handlers,
their names should be comma-separated, with whitespace allowed. (For example,
`reports = http, store`.)

This setting is relevant to puppet server and puppet apply. The primary Puppet
server will call these report handlers with the reports it receives from
agent nodes, and puppet apply will call them with its own report. (In
all cases, the node applying the catalog must have `report = true`.)

See the report reference for information on the built-in report
handlers; custom report handlers can also be loaded from modules.
(Report handlers are loaded from the lib directory, at
`puppet/reports/NAME.rb`.)

To turn off reports entirely, set this to `none`

- *Default*: `store`

### reporturl

The URL that reports should be forwarded to. This setting
is only used when the `http` report processor is enabled (see the
`reports` setting).

- *Default*: `http://localhost:3000/reports/upload`

### requestdir

Where host certificate requests are stored.

- *Default*: `$ssldir/certificate_requests`

### resourcefile

The file in which puppet agent stores a list of the resources
associated with the retrieved configuration.

- *Default*: `$statedir/resources.txt`

### resubmit_facts

Whether to send updated facts after every transaction. By default
puppet only submits facts at the beginning of the transaction before applying a
catalog. Since puppet can modify the state of the system, the value of the facts
may change after puppet finishes. Therefore, any facts stored in puppetdb may not
be consistent until the agent next runs, typically in 30 minutes. If this feature
is enabled, puppet will resubmit facts after applying its catalog, ensuring facts
for the node stored in puppetdb are current. However, this will double the fact
submission load on puppetdb, so it is disabled by default.

- *Default*: `false`

### rich_data

Enables having extended data in the catalog by storing them as a hash with the special key
`__ptype`. When enabled, resource containing values of the data types `Binary`, `Regexp`,
`SemVer`, `SemVerRange`, `Timespan` and `Timestamp`, as well as instances of types derived
from `Object` retain their data type.

- *Default*: `true`

### route_file

The YAML file containing indirector route configuration.

- *Default*: `$confdir/routes.yaml`

### rundir

Where Puppet PID files are kept.

- *Default*: `Unix/Linux: /var/run/puppetlabs -- Windows: C:\ProgramData\PuppetLabs\puppet\var\run -- Non-root user: ~/.puppetlabs/var/run`

### runinterval

How often puppet agent applies the catalog.
Note that a runinterval of 0 means "run continuously" rather than
"never run." This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `30m`

### runtimeout

The maximum amount of time an agent run is allowed to take.
A Puppet agent run that exceeds this timeout will be aborted. A value
of 0 disables the timeout. Defaults to 1 hour. This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `1h`

### serial

Where the serial number for certificates is stored.

- *Default*: `$cadir/serial`

### server

The primary Puppet server to which the Puppet agent should connect.

- *Default*: `puppet`

### server_datadir

The directory in which serialized data is stored, usually in a subdirectory.

- *Default*: `$vardir/server_data`

### server_list

The list of primary Puppet servers to which the Puppet agent should connect,
in the order that they will be tried. Each value should be a fully qualified domain name, followed by an optional ':' and port number. If a port is omitted, Puppet uses masterport for that host.

- *Default*: `[]`

### serverport

The default port puppet subcommands use to communicate
with Puppet Server. (eg `puppet facts upload`, `puppet agent`). May be
overridden by more specific settings (see `ca_port`, `report_port`).

- *Default*: `8140`

### settings_catalog

Whether to compile and apply the settings catalog

- *Default*: `true`

### show_diff

Whether to log and report a contextual diff when files are being replaced.
This causes partial file contents to pass through Puppet's normal
logging and reporting system, so this setting should be used with
caution if you are sending Puppet's reports to an insecure
destination. This feature currently requires the `diff/lcs` Ruby
library.

- *Default*: `false`

### signeddir

Where the CA stores signed certificates.

- *Default*: `$cadir/signed`

### skip_logging_catalog_request_destination

Specifies whether to suppress the notice of which compiler
supplied the catalog. A value of `true` suppresses the notice.

- *Default*: `false`

### skip_tags

Tags to use to filter resources.  If this is set, then
only resources not tagged with the specified tags will be applied.
Values must be comma-separated.


### sourceaddress

The address the agent should use to initiate requests.

- *Default*: ``

### splay

Whether to sleep for a random amount of time, ranging from
immediately up to its `$splaylimit`, before performing its first agent run
after a service restart. After this period, the agent runs periodically
on its `$runinterval`.

For example, assume a default 30-minute `$runinterval`, `splay` set to its
default of `false`, and an agent starting at :00 past the hour. The agent
would check in every 30 minutes at :01 and :31 past the hour.

With `splay` enabled, it waits any amount of time up to its `$splaylimit`
before its first run. For example, it might randomly wait 8 minutes,
then start its first run at :08 past the hour. With the `$runinterval`
at its default 30 minutes, its next run will be at :38 past the hour.

If you restart an agent's puppet service with `splay` enabled, it
recalculates its splay period and delays its first agent run after
restarting for this new period. If you simultaneously restart a group of
puppet agents with `splay` enabled, their checkins to your primary servers
can be distributed more evenly.

- *Default*: `false`

### splaylimit

The maximum time to delay before an agent's first run when
`splay` is enabled. Defaults to the agent's `$runinterval`. The
`splay` interval is random and recalculated each time the agent is started or
restarted. This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `$runinterval`

### srv_domain

The domain which will be queried to find the SRV records of servers to use.

- *Default*: `example.com`

### ssl_client_header

The header containing an authenticated client's SSL DN.
This header must be set by the proxy to the authenticated client's SSL
DN (e.g., `/CN=puppet.puppetlabs.com`).  Puppet will parse out the Common
Name (CN) from the Distinguished Name (DN) and use the value of the CN
field for authorization.

Note that the name of the HTTP header gets munged by the web server
common gateway interface: an `HTTP_` prefix is added, dashes are converted
to underscores, and all letters are uppercased.  Thus, to use the
`X-Client-DN` header, this setting should be `HTTP_X_CLIENT_DN`.

- *Default*: `HTTP_X_CLIENT_DN`

### ssl_client_verify_header

The header containing the status message of the client
verification. This header must be set by the proxy to 'SUCCESS' if the
client successfully authenticated, and anything else otherwise.

Note that the name of the HTTP header gets munged by the web server
common gateway interface: an `HTTP_` prefix is added, dashes are converted
to underscores, and all letters are uppercased.  Thus, to use the
`X-Client-Verify` header, this setting should be
`HTTP_X_CLIENT_VERIFY`.

- *Default*: `HTTP_X_CLIENT_VERIFY`

### ssl_lockfile

A lock file to indicate that the ssl bootstrap process is currently in progress.

- *Default*: `$ssldir/ssl.lock`

### ssl_trust_store

A file containing CA certificates in PEM format that puppet should trust
when making HTTPS requests. This **only** applies to https requests to non-puppet
infrastructure, such as retrieving file metadata and content from https file sources,
puppet module tool and the 'http' report processor. This setting is ignored when
making requests to puppet:// URLs such as catalog and report requests.

- *Default*: ``

### ssldir

Where SSL certificates are kept.

- *Default*: `$confdir/ssl`

### statedir

The directory where Puppet state is stored.  Generally,
this directory can be removed without causing harm (although it
might result in spurious service restarts).

- *Default*: `$vardir/state`

### statefile

Where Puppet agent and Puppet Server store state associated
with the running configuration.  In the case of Puppet Server,
this file reflects the state discovered through interacting
with clients.

- *Default*: `$statedir/state.yaml`

### statettl

How long the Puppet agent should cache when a resource was last checked or synced.
This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).
A value of `0` or `unlimited` will disable cache pruning.

This setting affects the usage of `schedule` resources, as the information
about when a resource was last checked (and therefore when it needs to be
checked again) is stored in the `statefile`. The `statettl` needs to be
large enough to ensure that a resource will not trigger multiple times
during a schedule due to its entry expiring from the cache.

- *Default*: `32d`

### static_catalogs

Whether to compile a [static catalog](https://puppet.com/docs/puppet/latest/static_catalogs.html#enabling-or-disabling-static-catalogs),
which occurs only on Puppet Server when the `code-id-command` and
`code-content-command` settings are configured in its `puppetserver.conf` file.

- *Default*: `true`

### storeconfigs

Whether to store each client's configuration, including catalogs, facts,
and related data. This also enables the import and export of resources in
the Puppet language - a mechanism for exchange resources between nodes.

By default this uses the 'puppetdb' backend.

You can adjust the backend using the storeconfigs_backend setting.

- *Default*: `false`

### storeconfigs_backend

Configure the backend terminus used for StoreConfigs.
By default, this uses the PuppetDB store, which must be installed
and configured before turning on StoreConfigs.

- *Default*: `puppetdb`

### strict

The strictness level of puppet. Allowed values are:

* off     - do not perform extra validation, do not report
* warning - perform extra validation, report as warning
* error   - perform extra validation, fail with error (default)

The strictness level is for both language semantics and runtime
evaluation validation. In addition to controlling the behavior with
this primary server switch some individual warnings may also be controlled
by the disable_warnings setting.

No new validations will be added to a micro (x.y.z) release,
but may be added in minor releases (x.y.0). In major releases
it expected that most (if not all) strictness validation become
standard behavior.

- *Default*: `error`

### strict_environment_mode

Whether the agent specified environment should be considered authoritative,
causing the run to fail if the retrieved catalog does not match it.

- *Default*: `false`

### strict_variables

Causes an evaluation error when referencing unknown variables. (This does not affect
referencing variables that are explicitly set to undef).

- *Default*: `true`

### summarize

Whether to print a transaction summary.

- *Default*: `false`

### supported_checksum_types

Checksum types supported by this agent for use in file resources of a
static catalog. Values must be comma-separated. Valid types are
sha256, sha256lite, sha384, sha512, sha224, sha1, sha1lite, md5, md5lite, mtime, ctime. Default is
sha256, sha384, sha512, sha224, md5.

- *Default*: `["sha256", "sha384", "sha512", "sha224", "md5"]`

### syslogfacility

What syslog facility to use when logging to syslog.
Syslog has a fixed list of valid facilities, and you must
choose one of those; you cannot just make one up.

- *Default*: `daemon`

### tags

Tags to use to find resources.  If this is set, then
only resources tagged with the specified tags will be applied.
Values must be comma-separated.


### tasks

Turns on experimental support for tasks and plans in the puppet language. This is for internal API use only.
Do not change this setting.

- *Default*: `false`

### top_level_facts_soft_limit

The soft limit for the number of top level facts.

- *Default*: `512`

### trace

Whether to print stack traces on some errors. Will print
internal Ruby stack trace interleaved with Puppet function frames.

- *Default*: `false`

### transactionstorefile

Transactional storage file for persisting data between
transactions for the purposes of inferring information (such as
corrective_change) on new data received.

- *Default*: `$statedir/transactionstore.yaml`

### trusted_external_command

The external trusted facts script or directory to use.
This setting's value can be set to the path to an executable command that
can produce external trusted facts or to a directory containing those
executable commands. The command(s) must:

* Take the name of a node as a command-line argument.
* Return a JSON hash with the external trusted facts for this node.
* For unknown or invalid nodes, exit with a non-zero exit code.

If the setting points to an executable command, then the external trusted
facts will be stored in the 'external' key of the trusted facts hash. Otherwise
for each executable file in the directory, the external trusted facts will be
stored in the `<basename>` key of the `trusted['external']` hash. For example,
if the files foo.rb and bar.sh are in the directory, then `trusted['external']`
will be the hash `{ 'foo' => <foo.rb output>, 'bar' => <bar.sh output> }`.

- *Default*: ``

### trusted_oid_mapping_file

File that provides mapping between custom SSL oids and user-friendly names

- *Default*: `$confdir/custom_trusted_oid_mapping.yaml`

### use_cached_catalog

Whether to only use the cached catalog rather than compiling a new catalog
on every run.  Puppet can be run with this enabled by default and then selectively
disabled when a recompile is desired. Because a Puppet agent using cached catalogs
does not contact the primary server for a new catalog, it also does not upload facts at
the beginning of the Puppet run.

- *Default*: `false`

### use_last_environment

Puppet saves both the initial and converged environment in the last_run_summary file.
If they differ, and this setting is set to true, we will use the last converged
environment and skip the node request.

When set to false, we will do the node request and ignore the environment data from the last_run_summary file.

- *Default*: `true`

### use_srv_records

Whether the server will search for SRV records in DNS for the current domain.

- *Default*: `false`

### usecacheonfailure

Whether to use the cached configuration when the remote
configuration will not compile.  This option is useful for testing
new configurations, where you want to fix the broken configuration
rather than reverting to a known-good one.

- *Default*: `true`

### user

The user Puppet Server will run as. Used to ensure
the agent side processes (agent, apply, etc) create files and
directories readable by Puppet Server when necessary.

- *Default*: `puppet`

### vardir

Where Puppet stores dynamic and growing data.  The default for this
setting is calculated specially, like `confdir`_.

- *Default*: `Unix/Linux: /opt/puppetlabs/puppet/cache -- Windows: C:\ProgramData\PuppetLabs\puppet\cache -- Non-root user: ~/.puppetlabs/opt/puppet/cache`

### vendormoduledir

The directory containing **vendored** modules. These modules will
be used by _all_ environments like those in the `basemodulepath`. The only
difference is that modules in the `basemodulepath` are pluginsynced, while
vendored modules are not

- *Default*: `/opt/puppetlabs/puppet/vendor_modules`

### versioned_environment_dirs

Whether or not to look for versioned environment directories,
symlinked from `$environmentpath/<environment>`. This is an experimental
feature and should be used with caution.

- *Default*: `false`

### waitforcert

How frequently puppet agent should ask for a signed certificate.

When starting for the first time, puppet agent will submit a certificate
signing request (CSR) to the server named in the `ca_server` setting
(usually the primary Puppet server); this may be autosigned, or may need to be
approved by a human, depending on the CA server's configuration.

Puppet agent cannot apply configurations until its approved certificate is
available. Since the certificate may or may not be available immediately,
puppet agent will repeatedly try to fetch it at this interval. You can
turn off waiting for certificates by specifying a time of 0, or a maximum
amount of time to wait in the `maxwaitforcert` setting, in which case
puppet agent will exit if it cannot get a cert.
This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `2m`

### waitforlock

How frequently puppet agent should try running when there is an
already ongoing puppet agent instance.

This argument is by default disabled (value set to 0). In this case puppet agent will
immediately exit if it cannot run at that moment. When a value other than 0 is set, this
can also be used in combination with the `maxwaitforlock` argument.
This setting can be a time interval in seconds (30 or 30s), minutes (30m), hours (6h), days (2d), or years (5y).

- *Default*: `0`

### write_catalog_summary

Whether to write the `classfile` and `resourcefile` after applying
the catalog. It is enabled by default, except when running `puppet apply`.

- *Default*: `true`

### yamldir

The directory in which YAML data is stored, usually in a subdirectory.

- *Default*: `$vardir/yaml`

