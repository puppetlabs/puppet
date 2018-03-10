require 'puppet/application'
require 'puppet/ssl/certificate_authority/interface'

class Puppet::Application::Cert < Puppet::Application

  run_mode :master

  attr_accessor :all, :ca, :digest, :signed

  def subcommand
    @subcommand
  end

  def subcommand=(name)
    # Handle the nasty, legacy mapping of "clean" to "destroy".
    sub = name.to_sym
    @subcommand = (sub == :clean ? :destroy : sub)
  end

  option("--clean", "-c") do |arg|
    self.subcommand = "destroy"
  end

  option("--all", "-a") do |arg|
    @all = true
  end

  option("--digest DIGEST") do |arg|
    @digest = arg
  end

  option("--signed", "-s") do |arg|
    @signed = true
  end

  option("--debug", "-d") do |arg|
    options[:debug] = true
    set_log_level
  end

  option("--list", "-l") do |arg|
    self.subcommand = :list
  end

  option("--revoke", "-r") do |arg|
    self.subcommand = :revoke
  end

  option("--generate", "-g") do |arg|
    self.subcommand = :generate
  end

  option("--sign", "-s") do |arg|
    self.subcommand = :sign
  end

  option("--print", "-p") do |arg|
    self.subcommand = :print
  end

  option("--verify", "-v") do |arg|
    self.subcommand = :verify
  end

  option("--fingerprint", "-f") do |arg|
    self.subcommand = :fingerprint
  end

  option("--reinventory") do |arg|
    self.subcommand = :reinventory
  end

  option("--[no-]allow-dns-alt-names") do |value|
    options[:allow_dns_alt_names] = value
  end

  option("--[no-]allow-authorization-extensions") do |value|
    options[:allow_authorization_extensions] = value
  end

  option("--verbose", "-v") do |arg|
    options[:verbose] = true
    set_log_level
  end

  option("--human-readable", "-H") do |arg|
    options[:format] = :human
  end

  option("--machine-readable", "-m") do |arg|
    options[:format] = :machine
  end

  option("--interactive", "-i") do |arg|
    options[:interactive] = true
  end

  option("--assume-yes", "-y") do |arg|
    options[:yes] = true
  end

  def summary
    _("Manage certificates and requests")
  end

  def help
    <<-HELP

puppet-cert(8) -- #{summary}
========

SYNOPSIS
--------
Standalone certificate authority. Capable of generating certificates,
but mostly used for signing certificate requests from puppet clients.


USAGE
-----
puppet cert <action> [-h|--help] [-V|--version] [-d|--debug] [-v|--verbose]
  [--digest <digest>] [<host>]


DESCRIPTION
-----------
Because the puppet master service defaults to not signing client
certificate requests, this script is available for signing outstanding
requests. It can be used to list outstanding requests and then either
sign them individually or sign all of them.

ACTIONS
-------

Every action except 'list' and 'generate' requires a hostname to act on,
unless the '--all' option is set.

The most important actions for day-to-day use are 'list' and 'sign'.

* clean:
  Revoke a host's certificate (if applicable) and remove all files
  related to that host from puppet cert's storage. This is useful when
  rebuilding hosts, since new certificate signing requests will only be
  honored if puppet cert does not have a copy of a signed certificate
  for that host. If '--all' is specified then all host certificates,
  both signed and unsigned, will be removed.

* fingerprint:
  Print the DIGEST (defaults to the signing algorithm) fingerprint of a
  host's certificate.

* generate:
  Generate a certificate for a named client. A certificate/keypair will
  be generated for each client named on the command line.

* list:
  List outstanding certificate requests. If '--all' is specified, signed
  certificates are also listed, prefixed by '+', and revoked or invalid
  certificates are prefixed by '-' (the verification outcome is printed
  in parenthesis). If '--human-readable' or '-H' is specified,
  certificates are formatted in a way to improve human scan-ability. If
  '--machine-readable' or '-m' is specified, output is formatted concisely
  for consumption by a script.

* print:
  Print the full-text version of a host's certificate.

* revoke:
  Revoke the certificate of a client. The certificate can be specified either
  by its serial number (given as a hexadecimal number prefixed by '0x') or by its
  hostname. The certificate is revoked by adding it to the Certificate Revocation
  List given by the 'cacrl' configuration option. Note that the puppet master
  needs to be restarted after revoking certificates.

* sign:
  Sign an outstanding certificate request. If '--interactive' or '-i' is
  supplied the user will be prompted to confirm that they are signing the
  correct certificate (recommended). If '--assume-yes' or '-y' is supplied
  the interactive prompt will assume the answer of 'yes'.

* verify:
  Verify the named certificate against the local CA certificate.

* reinventory:
  Build an inventory of the issued certificates. This will destroy the current
  inventory file specified by 'cert_inventory' and recreate it from the
  certificates found in the 'certdir'. Ensure the puppet master is stopped
  before running this action.

OPTIONS
-------
Note that any setting that's valid in the configuration
file is also a valid long argument. For example, 'ssldir' is a valid
setting, so you can specify '--ssldir <directory>' as an
argument.

See the configuration file documentation at
https://docs.puppetlabs.com/puppet/latest/reference/configuration.html for the
full list of acceptable parameters. A commented list of all
configuration options can also be generated by running puppet cert with
'--genconfig'.

* --all:
  Operate on all items. Currently only makes sense with the 'sign',
  'list', and 'fingerprint' actions.

* --allow-dns-alt-names:
  Sign a certificate request even if it contains one or more alternate DNS
  names. If this option isn't specified, 'puppet cert sign' will ignore any
  requests that contain alternate names.

  In general, ONLY certs intended for a Puppet master server should include
  alternate DNS names, since Puppet agent relies on those names for identifying
  its rightful server.

  You can make Puppet agent request a certificate with alternate names by
  setting 'dns_alt_names' in puppet.conf or specifying '--dns_alt_names' on the
  command line. The output of 'puppet cert list' shows any requested alt names
  for pending certificate requests.

* --allow-authorization-extensions:
  Enable the signing of a request with authorization extensions. Such requests
  are sensitive because they can be used to write access rules in Puppet Server.
  Currently, this is the only means by which such requests can be signed.

* --digest:
  Set the digest for fingerprinting (defaults to the digest used when
  signing the cert). Valid values depends on your openssl and openssl ruby
  extension version.

* --debug:
  Enable full debugging.

* --help:
  Print this help message

* --verbose:
  Enable verbosity.

* --version:
  Print the puppet version number and exit.


EXAMPLE
-------
    $ puppet cert list
    culain.madstop.com
    $ puppet cert sign culain.madstop.com


AUTHOR
------
Luke Kanies


COPYRIGHT
---------
Copyright (c) 2011 Puppet Inc., LLC Licensed under the Apache 2.0 License

    HELP
  end

  def main
    if @all
      hosts = :all
    elsif @signed
      hosts = :signed
    else
      hosts = command_line.args.collect { |h| h.downcase }
    end
    begin
      if subcommand == :destroy
        raise _("Refusing to destroy all certs, provide an explicit list of certs to destroy") if hosts == :all

        signed_hosts = hosts - @ca.waiting?
        apply(@ca, :revoke, options.merge(:to => signed_hosts)) unless signed_hosts.empty?
      end
      apply(@ca, subcommand, options.merge(:to => hosts, :digest => @digest))
    rescue => detail
      Puppet.log_exception(detail)
      exit(24)
    end
  end

  def setup
    require 'puppet/ssl/certificate_authority'
    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    Puppet::SSL::Oids.register_puppet_oids
    Puppet::SSL::Oids.load_custom_oid_file(Puppet[:trusted_oid_mapping_file])

    Puppet::Util::Log.newdestination :console

    if [:generate, :destroy].include? subcommand
      Puppet::SSL::Host.ca_location = :local
    else
      Puppet::SSL::Host.ca_location = :only
    end

    # If we are generating, and the option came from the CLI, it gets added to
    # the data.  This will do the right thing for non-local certificates, in
    # that the command line but *NOT* the config file option will apply.
    if subcommand == :generate
      if Puppet.settings.set_by_cli?(:dns_alt_names)
        options[:dns_alt_names] = Puppet[:dns_alt_names]
      end
    end

    begin
      @ca = Puppet::SSL::CertificateAuthority.new
    rescue => detail
      Puppet.log_exception(detail)
      exit(23)
    end
  end

  def parse_options
    # handle the bareword subcommand pattern.
    result = super
    unless self.subcommand then
      if sub = self.command_line.args.shift then
        self.subcommand = sub
      else
        puts help
        exit
      end
    end

    result
  end

  # Create and run an applicator.  I wanted to build an interface where you could do
  # something like 'ca.apply(:generate).to(:all) but I don't think it's really possible.
  def apply(ca, method, options)
    raise ArgumentError, _("You must specify the hosts to apply to; valid values are an array or the symbol :all") unless options[:to]
    applier = Puppet::SSL::CertificateAuthority::Interface.new(method, options)
    applier.apply(ca)
  end

end
