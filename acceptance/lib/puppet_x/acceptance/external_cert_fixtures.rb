module PuppetX
module Acceptance
class ExternalCertFixtures
  attr_reader :fixture_dir
  attr_reader :test_dir
  attr_reader :master_name
  attr_reader :agent_name

  ##
  # ExternalCerts provides a utility class to fill in fixture data and other
  # large blobs of text configuration for the acceptance testing of External CA
  # behavior.
  #
  # @param [String] fixture_dir The fixture directory to read from.
  #
  # @param [String] test_dir The directory on the remote system, used for
  # filling in templates.
  #
  # @param [String] master_name The common name the master should be reachable
  #   at.  This name should match up with the certificate files in the fixture
  #   directory, e.g. master1.example.org.
  #
  # @param [String] agent_name The common name the agent is configured to use.
  #   This name should match up with the certificate files in the fixture
  #   directory, e.g.
  def initialize(fixture_dir, test_dir, master_name = "master1.example.org", agent_name = "agent1.example.org")
    @fixture_dir = fixture_dir
    @test_dir = test_dir
    @master_name = master_name
    @agent_name = agent_name
  end

  def master_short_name
    @master_short_name ||= master_name.gsub(/\..*/, '')
  end

  def host_entry
    @host_entry ||= "127.0.0.3 #{master_name} #{master_short_name} puppet"
  end

  def root_ca_cert
    @root_ca_cert ||= File.read(File.join(fixture_dir, 'root', 'ca-root.crt'))
  end

  def agent_ca_cert
    @agent_ca_cert ||= File.read(File.join(fixture_dir, 'agent-ca', 'ca-agent-ca.crt'))
  end

  def master_ca_cert
    @master_ca_cert ||= File.read(File.join(fixture_dir, 'master-ca', 'ca-master-ca.crt'))
  end

  def master_ca_crl
    @master_ca_crl ||= File.read(File.join(fixture_dir, 'master-ca', 'ca-master-ca.crl'))
  end

  def agent_cert
    @agent_cert ||= File.read(File.join(fixture_dir, 'leaves', "#{agent_name}.issued_by.agent-ca.crt"))
  end

  def agent_key
    @agent_key ||= File.read(File.join(fixture_dir, 'leaves', "#{agent_name}.issued_by.agent-ca.key"))
  end

  def agent_email_cert
    @agent_email_cert ||= File.read(File.join(fixture_dir, 'leaves', "#{agent_name}.email.issued_by.agent-ca.crt"))
  end

  def agent_email_key
    @agent_email_cert ||= File.read(File.join(fixture_dir, 'leaves', "#{agent_name}.email.issued_by.agent-ca.key"))
  end

  def master_cert
    @master_cert ||= File.read(File.join(fixture_dir, 'leaves', "#{master_name}.issued_by.master-ca.crt"))
  end

  def master_key
    @master_key ||= File.read(File.join(fixture_dir, 'leaves', "#{master_name}.issued_by.master-ca.key"))
  end

  def master_cert_rogue
    @master_cert_rogue ||= File.read(File.join(fixture_dir, 'leaves', "#{master_name}.issued_by.agent-ca.crt"))
  end

  def master_key_rogue
    @master_key_rogue ||= File.read(File.join(fixture_dir, 'leaves', "#{master_name}.issued_by.agent-ca.key"))
  end

  ## Configuration files
  def agent_conf
    @agent_conf ||= <<-EO_AGENT_CONF
[main]
color = false
certname = #{agent_name}
server = #{master_name}
certificate_revocation = false

# localcacert must contain the Root CA certificate to complete the 2 level CA
# chain when an intermediate CA certificate is being used.  Either the HTTP
# server must send the intermediate certificate during the handshake, or the
# agent must use the `ssl_client_ca_auth` setting to provide the client
# certificate.
localcacert = #{test_dir}/ca_root.crt
EO_AGENT_CONF
  end

  def agent_conf_email
    @agent_conf ||= <<-EO_AGENT_CONF
[main]
color = false
certname = #{agent_name}
server = #{master_name}
certificate_revocation = false
hostcert = #{test_dir}/agent_email.crt
hostkey = #{test_dir}/agent_email.key
localcacert = #{test_dir}/ca_root.crt
EO_AGENT_CONF
  end

  def agent_conf_crl
    @agent_conf_crl ||= <<-EO_AGENT_CONF
[main]
certname = #{agent_name}
server = #{master_name}

# localcacert must contain the Root CA certificate to complete the 2 level CA
# chain when an intermediate CA certificate is being used.  Either the HTTP
# server must send the intermediate certificate during the handshake, or the
# agent must use the `ssl_client_ca_auth` setting to provide the client
# certificate.
localcacert = #{test_dir}/ca_root.crt
EO_AGENT_CONF
  end

  def master_conf
    @master_conf ||= <<-EO_MASTER_CONF
[master]
ca = false
certname = #{master_name}
ssl_client_header = HTTP_X_CLIENT_DN
ssl_client_verify_header = HTTP_X_CLIENT_VERIFY
EO_MASTER_CONF
  end

  ##
  # Passenger Rack compliant config.ru which is responsible for starting the
  # Puppet master.
  def config_ru
    @config_ru ||= <<-EO_CONFIG_RU
\$0 = "master"
ARGV << "--rack"
ARGV << "--confdir=#{test_dir}/etc/master"
ARGV << "--vardir=#{test_dir}/etc/master/var"
require 'puppet/util/command_line'
run Puppet::Util::CommandLine.new.execute
EO_CONFIG_RU
  end

  ##
  # auth_conf should return auth authorization file that allows *.example.org
  # access to to the full REST API.
  def auth_conf
    @auth_conf_content ||= File.read(File.join(fixture_dir, 'auth.conf'))
  end

  ##
  # Apache configuration with Passenger
  def httpd_conf
    @httpd_conf ||= <<-EO_HTTPD_CONF
User apache
Group apache

ServerRoot "/etc/httpd"
PidFile run/httpd.pid
Timeout 60
KeepAlive Off
MaxKeepAliveRequests 100
KeepAliveTimeout 15

<IfModule prefork.c>
StartServers       8
MinSpareServers    5
MaxSpareServers   20
ServerLimit      256
MaxClients       256
MaxRequestsPerChild  4000
</IfModule>

<IfModule worker.c>
StartServers         4
MaxClients         300
MinSpareThreads     25
MaxSpareThreads     75
ThreadsPerChild     25
MaxRequestsPerChild  0
</IfModule>

LoadModule auth_basic_module modules/mod_auth_basic.so
LoadModule auth_digest_module modules/mod_auth_digest.so
LoadModule authn_file_module modules/mod_authn_file.so
LoadModule authn_alias_module modules/mod_authn_alias.so
LoadModule authn_anon_module modules/mod_authn_anon.so
LoadModule authn_dbm_module modules/mod_authn_dbm.so
LoadModule authn_default_module modules/mod_authn_default.so
LoadModule authz_host_module modules/mod_authz_host.so
LoadModule authz_user_module modules/mod_authz_user.so
LoadModule authz_owner_module modules/mod_authz_owner.so
LoadModule authz_groupfile_module modules/mod_authz_groupfile.so
LoadModule authz_dbm_module modules/mod_authz_dbm.so
LoadModule authz_default_module modules/mod_authz_default.so
LoadModule ldap_module modules/mod_ldap.so
LoadModule authnz_ldap_module modules/mod_authnz_ldap.so
LoadModule include_module modules/mod_include.so
LoadModule log_config_module modules/mod_log_config.so
LoadModule logio_module modules/mod_logio.so
LoadModule env_module modules/mod_env.so
LoadModule ext_filter_module modules/mod_ext_filter.so
LoadModule mime_magic_module modules/mod_mime_magic.so
LoadModule expires_module modules/mod_expires.so
LoadModule deflate_module modules/mod_deflate.so
LoadModule headers_module modules/mod_headers.so
LoadModule usertrack_module modules/mod_usertrack.so
LoadModule setenvif_module modules/mod_setenvif.so
LoadModule mime_module modules/mod_mime.so
LoadModule dav_module modules/mod_dav.so
LoadModule status_module modules/mod_status.so
LoadModule autoindex_module modules/mod_autoindex.so
LoadModule info_module modules/mod_info.so
LoadModule dav_fs_module modules/mod_dav_fs.so
LoadModule vhost_alias_module modules/mod_vhost_alias.so
LoadModule negotiation_module modules/mod_negotiation.so
LoadModule dir_module modules/mod_dir.so
LoadModule actions_module modules/mod_actions.so
LoadModule speling_module modules/mod_speling.so
LoadModule userdir_module modules/mod_userdir.so
LoadModule alias_module modules/mod_alias.so
LoadModule substitute_module modules/mod_substitute.so
LoadModule rewrite_module modules/mod_rewrite.so
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_balancer_module modules/mod_proxy_balancer.so
LoadModule proxy_ftp_module modules/mod_proxy_ftp.so
LoadModule proxy_http_module modules/mod_proxy_http.so
LoadModule proxy_ajp_module modules/mod_proxy_ajp.so
LoadModule proxy_connect_module modules/mod_proxy_connect.so
LoadModule cache_module modules/mod_cache.so
LoadModule suexec_module modules/mod_suexec.so
LoadModule disk_cache_module modules/mod_disk_cache.so
LoadModule cgi_module modules/mod_cgi.so
LoadModule version_module modules/mod_version.so

LoadModule ssl_module modules/mod_ssl.so
LoadModule passenger_module modules/mod_passenger.so

ServerName #{master_name}
DocumentRoot "#{test_dir}/etc/master/public"

DefaultType text/plain
TypesConfig /etc/mime.types

# Same thing, just using a certificate issued by the Agent CA, which should not
# be trusted by the clients.

Listen 8140 https
Listen 8141 https

<VirtualHost _default_:8140>
    SSLEngine on
    SSLProtocol ALL -SSLv2
    SSLCipherSuite ALL:!ADH:RC4+RSA:+HIGH:+MEDIUM:-LOW:-SSLv2:-EXP

    SSLCertificateFile "#{test_dir}/master.crt"
    SSLCertificateKeyFile "#{test_dir}/master.key"

    # The chain file is sent to the client during handshake.
    SSLCertificateChainFile "#{test_dir}/ca_master_bundle.crt"
    # The CA cert file is used to authenticate clients
    SSLCACertificateFile "#{test_dir}/ca_agent_bundle.crt"

    SSLVerifyClient optional
    SSLVerifyDepth 2
    SSLOptions +StdEnvVars
    RequestHeader set X-SSL-Subject %{SSL_CLIENT_S_DN}e
    RequestHeader set X-Client-DN %{SSL_CLIENT_S_DN}e
    RequestHeader set X-Client-Verify %{SSL_CLIENT_VERIFY}e

    DocumentRoot "#{test_dir}/etc/master/public"

    PassengerRoot /usr/share/gems/gems/passenger-3.0.17
    PassengerRuby /usr/bin/ruby

    RackAutoDetect On
    RackBaseURI /
</VirtualHost>

<VirtualHost _default_:8141>
    SSLEngine on
    SSLProtocol ALL -SSLv2
    SSLCipherSuite ALL:!ADH:RC4+RSA:+HIGH:+MEDIUM:-LOW:-SSLv2:-EXP
    SSLCertificateFile "#{test_dir}/master_rogue.crt"
    SSLCertificateKeyFile "#{test_dir}/master_rogue.key"

    SSLCertificateChainFile "#{test_dir}/ca_agent_bundle.crt"
    SSLCACertificateFile "#{test_dir}/ca_agent_bundle.crt"

    SSLVerifyClient optional
    SSLVerifyDepth 2
    SSLOptions +StdEnvVars
    RequestHeader set X-SSL-Subject %{SSL_CLIENT_S_DN}e
    RequestHeader set X-Client-DN %{SSL_CLIENT_S_DN}e
    RequestHeader set X-Client-Verify %{SSL_CLIENT_VERIFY}e

    DocumentRoot "#{test_dir}/etc/master/public"

    PassengerRoot /usr/share/gems/gems/passenger-3.0.17
    PassengerRuby /usr/bin/ruby

    RackAutoDetect On
    RackBaseURI /
</VirtualHost>
EO_HTTPD_CONF
  end

  ##
  # webserver.conf for a trustworthy master for use with Jetty
  def jetty_webserver_conf_for_trustworthy_master
    @jetty_webserver_conf_for_trustworthy_master ||= <<-EO_WEBSERVER_CONF
webserver: {
    client-auth: want
    ssl-host: 0.0.0.0
    ssl-port: 8140

    ssl-cert: "#{test_dir}/master.crt"
    ssl-key: "#{test_dir}/master.key"

    ssl-cert-chain: "#{test_dir}/ca_master_bundle.crt"
    ssl-ca-cert: "#{test_dir}/ca_agent_bundle.crt"
}
    EO_WEBSERVER_CONF
  end

  ##
  # webserver.conf for a rogue master for use with Jetty
  def jetty_webserver_conf_for_rogue_master
    @jetty_webserver_conf_for_rogue_master ||= <<-EO_WEBSERVER_CONF
webserver: {
    client-auth: want
    ssl-host: 0.0.0.0
    ssl-port: 8140

    ssl-cert: "#{test_dir}/master_rogue.crt"
    ssl-key: "#{test_dir}/master_rogue.key"

    ssl-cert-chain: "#{test_dir}/ca_agent_bundle.crt"
    ssl-ca-cert: "#{test_dir}/ca_agent_bundle.crt"
}
    EO_WEBSERVER_CONF
  end

end
end
end
