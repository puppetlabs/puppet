begin
  require 'puppet_x/acceptance/external_cert_fixtures'
rescue LoadError
  $LOAD_PATH.unshift(File.expand_path('../../../lib', __FILE__))
  require 'puppet_x/acceptance/external_cert_fixtures'
end

confine :except, :type => 'pe'

skip_test "Test only supported on Jetty" unless @options[:is_puppetserver]

# Verify that a trivial manifest can be run to completion.
# Supported Setup: Single, Root CA
#  - Agent and Master SSL cert issued by the Root CA
#  - Revocation disabled on the agent `certificate_revocation = false`
#  - CA disabled on the master `ca = false`
#
test_name "Puppet agent and master work when both configured with externally issued certificates from independent intermediate CAs"

tag 'audit:medium',
    'audit:integration',  # This could also be a component in a platform workflow test.
    'server'

step "Copy certificates and configuration files to the master..."
fixture_dir = File.expand_path('../fixtures', __FILE__)
testdir = master.tmpdir('jetty_external_root_ca')
backupdir = master.tmpdir('jetty_external_root_ca_backup')
fixtures = PuppetX::Acceptance::ExternalCertFixtures.new(fixture_dir, testdir)

jetty_confdir = master['puppetserver-confdir']

# Register our cleanup steps early in a teardown so that they will happen even
# if execution aborts part way.
teardown do
  step "Restore /etc/hosts and puppetserver configs; Restart puppetserver"
  on master, "cp -p '#{backupdir}/hosts' /etc/hosts"
  on master, puppet('config set route_file /etc/puppetlabs/puppet/routes.yaml')

  # Please note that the escaped `\cp` command below is intentional. Most
  # linux systems alias `cp` to `cp -i` which causes interactive mode to be
  # invoked when copying directories that do not yet exist at the target
  # location, even when using the force flag. The escape ensures that an
  # alias is not used.
  on master, "\\cp -frp #{backupdir}/puppetserver/* #{jetty_confdir}/../"
  on(master, "service #{master['puppetservice']} restart")
end

# Backup files in scope for modification by test
on master, "cp -p /etc/hosts '#{backupdir}/hosts'"
on master, "cp -rp '#{jetty_confdir}/..' '#{backupdir}/puppetserver'"


# Read all of the CA certificates.

# Copy all of the x.509 fixture data over to the master.
create_remote_file master, "#{testdir}/ca_root.crt", fixtures.root_ca_cert
create_remote_file master, "#{testdir}/ca_agent.crt", fixtures.agent_ca_cert
create_remote_file master, "#{testdir}/ca_master.crt", fixtures.master_ca_cert
create_remote_file master, "#{testdir}/ca_master.crl", fixtures.master_ca_crl
create_remote_file master, "#{testdir}/ca_master_bundle.crt", "#{fixtures.master_ca_cert}\n#{fixtures.root_ca_cert}\n"
create_remote_file master, "#{testdir}/ca_agent_bundle.crt", "#{fixtures.agent_ca_cert}\n#{fixtures.root_ca_cert}\n"
create_remote_file master, "#{testdir}/agent.crt", fixtures.agent_cert
create_remote_file master, "#{testdir}/agent.key", fixtures.agent_key
create_remote_file master, "#{testdir}/agent_email.crt", fixtures.agent_email_cert
create_remote_file master, "#{testdir}/agent_email.key", fixtures.agent_email_key
create_remote_file master, "#{testdir}/master.crt", fixtures.master_cert
create_remote_file master, "#{testdir}/master.key", fixtures.master_key
create_remote_file master, "#{testdir}/master_rogue.crt", fixtures.master_cert_rogue
create_remote_file master, "#{testdir}/master_rogue.key", fixtures.master_key_rogue

##
# Now create the master and agent puppet.conf
#
on master, "mkdir -p #{testdir}/etc/agent"

# Make master1.example.org resolve if it doesn't already.
on master, "grep -q -x '#{fixtures.host_entry}' /etc/hosts || echo '#{fixtures.host_entry}' >> /etc/hosts"

create_remote_file master, "#{testdir}/etc/agent/puppet.conf", fixtures.agent_conf
create_remote_file master, "#{testdir}/etc/agent/puppet.conf.crl", fixtures.agent_conf_crl
create_remote_file master, "#{testdir}/etc/agent/puppet.conf.email", fixtures.agent_conf_email

# auth.conf to allow *.example.com access to the rest API
create_remote_file master, "#{jetty_confdir}/auth.conf", fixtures.auth_conf
# set use-legacy-auth-conf = false
# to override the default setting in older puppetserver versions
modify_tk_config(master, options['puppetserver-config'], {'jruby-puppet' => {'use-legacy-auth-conf' => false}})

step "Set filesystem permissions and ownership for the master"
# These permissions are required for the JVM to start Puppet as puppet
on master, "chown -R puppet:puppet #{testdir}/*.{crt,key,crl}"

# These permissions are just for testing, end users should protect their
# private keys.
on master, "chmod -R a+rX #{testdir}"

agent_cmd_prefix = "--confdir #{testdir}/etc/agent --vardir #{testdir}/etc/agent/var"

# Move the agent SSL cert and key into place.
# The filename must match the configured certname, otherwise Puppet will try
# and generate a new certificate and key
step "Configure the agent with the externally issued certificates"
on master, "mkdir -p #{testdir}/etc/agent/ssl/{public_keys,certs,certificate_requests,private_keys,private}"
create_remote_file master, "#{testdir}/etc/agent/ssl/certs/#{fixtures.agent_name}.pem", fixtures.agent_cert
create_remote_file master, "#{testdir}/etc/agent/ssl/private_keys/#{fixtures.agent_name}.pem", fixtures.agent_key

create_remote_file master, "#{jetty_confdir}/webserver.conf",
                   fixtures.jetty_webserver_conf_for_trustworthy_master

master_opts = {
    'master' => {
        'certname' => fixtures.master_name,
        'ssl_client_header' => "HTTP_X_CLIENT_DN",
        'ssl_client_verify_header' => "HTTP_X_CLIENT_VERIFY"
    }
}

# disable CA service
# https://github.com/puppetlabs/puppetserver/blob/master/documentation/configuration.markdown#service-bootstrapping
create_remote_file master, "#{jetty_confdir}/../services.d/ca.cfg", "puppetlabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service"
# disable pdb connectivity
on master, puppet('config set route_file /tmp/nonexistent.yaml')
# restart master
on(master, "service #{master['puppetservice']} restart")

step "Start the Puppet master service..."
with_puppet_running_on(master, master_opts) do
  # Now, try and run the agent on the master against itself.
  step "Successfully run the puppet agent on the master"
  on master, puppet_agent("#{agent_cmd_prefix} --test"), :acceptable_exit_codes => (0..255) do
    assert_no_match /Creating a new SSL key/, stdout
    assert_no_match /\Wfailed\W/i, stderr
    assert_no_match /\Wfailed\W/i, stdout
    assert_no_match /\Werror\W/i, stderr
    assert_no_match /\Werror\W/i, stdout
    # Assert the exit code so we get a "Failed test" instead of an "Errored test"
    assert exit_code == 0
  end

  step "Master accepts client cert with email address in subject"
  on master, "cp #{testdir}/etc/agent/puppet.conf{,.no_email}"
  on master, "cp #{testdir}/etc/agent/puppet.conf{.email,}"
  on master, puppet_agent("#{agent_cmd_prefix} --test"), :acceptable_exit_codes => (0..255) do
    assert_no_match /\Wfailed\W/i, stdout
    assert_no_match /\Wfailed\W/i, stderr
    assert_no_match /\Werror\W/i, stdout
    assert_no_match /\Werror\W/i, stderr
    # Assert the exit code so we get a "Failed test" instead of an "Errored test"
    assert exit_code == 0
  end

  step "Agent refuses to connect to revoked master"
  on master, "cp #{testdir}/etc/agent/puppet.conf{,.no_crl}"
  on master, "cp #{testdir}/etc/agent/puppet.conf{.crl,}"

  revoke_opts = "--hostcrl #{testdir}/ca_master.crl"
  on master, puppet_agent("#{agent_cmd_prefix} #{revoke_opts} --test"), :acceptable_exit_codes => (0..255) do
    assert_match /certificate revoked.*?example.org/, stderr
    assert exit_code == 1
  end
end

create_remote_file master, "#{jetty_confdir}/webserver.conf",
                   fixtures.jetty_webserver_conf_for_rogue_master

with_puppet_running_on(master, master_opts) do
  step "Agent refuses to connect to a rogue master"
  on master, puppet_agent("#{agent_cmd_prefix} --ssl_client_ca_auth=#{testdir}/ca_master.crt --test"), :acceptable_exit_codes => (0..255) do
    assert_no_match /Creating a new SSL key/, stdout
    assert_match /certificate verify failed/i, stderr
    assert_match /The server presented a SSL certificate chain which does not include a CA listed in the ssl_client_ca_auth file/i, stderr
    assert exit_code == 1
  end
end

step "Finished testing External Certificates"
