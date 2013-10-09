begin
  require 'puppet_x/acceptance/external_cert_fixtures'
rescue LoadError
  $LOAD_PATH.unshift(File.expand_path('../../../lib', __FILE__))
  require 'puppet_x/acceptance/external_cert_fixtures'
end

# This test only runs on EL-6 master roles.
confine :to, :platform => 'el-6'
confine :except, :type => 'pe'

# Verify that a trivial manifest can be run to completion.
# Supported Setup: Single, Root CA
#  - Agent and Master SSL cert issued by the Root CA
#  - Revocation disabled on the agent `certificate_revocation = false`
#  - CA disabled on the master `ca = false`
#
# SUPPORT NOTES
#
# * If the x509 alt names extension is used when issuing SSL server certificates
#   for the Puppet master, then the client SSL certificate issued by an external
#   CA must posses the DNS common name in the alternate name field.  This is
#   due to a bug in Ruby.  If the CN is not duplicated in the Alt Names, then
#   the following error will appear on the agent with MRI 1.8.7:
#
#   Warning: Server hostname 'master1.example.org' did not match server
#   certificate; expected one of master1.example.org, DNS:puppet,
#   DNS:master-ca.example.org
#
#   See: https://bugs.ruby-lang.org/issues/6493
test_name "Puppet agent works with Apache, both configured with externally issued certificates from independent intermediate CA's"

step "Copy certificates and configuration files to the master..."
fixture_dir = File.expand_path('../fixtures', __FILE__)
testdir = master.tmpdir('apache_external_root_ca')
fixtures = PuppetX::Acceptance::ExternalCertFixtures.new(fixture_dir, testdir)

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
# We need to create the public directory for Passenger and the modules
# directory to avoid `Error: Could not evaluate: Could not retrieve information
# from environment production source(s) puppet://master1.example.org/plugins`
on master, "mkdir -p #{testdir}/etc/{master/{public,modules/empty/lib},agent}"
# Backup /etc/hosts
on master, "cp -p /etc/hosts '#{testdir}/hosts'"

# Make master1.example.org resolve if it doesn't already.
on master, "grep -q -x '#{fixtures.host_entry}' /etc/hosts || echo '#{fixtures.host_entry}' >> /etc/hosts"

create_remote_file master, "#{testdir}/etc/agent/puppet.conf", fixtures.agent_conf
create_remote_file master, "#{testdir}/etc/agent/puppet.conf.crl", fixtures.agent_conf_crl
create_remote_file master, "#{testdir}/etc/agent/puppet.conf.email", fixtures.agent_conf_email
create_remote_file master, "#{testdir}/etc/master/puppet.conf", fixtures.master_conf

# auth.conf to allow *.example.com access to the rest API
create_remote_file master, "#{testdir}/etc/master/auth.conf", fixtures.auth_conf

create_remote_file master, "#{testdir}/etc/master/config.ru", fixtures.config_ru

step "Set filesystem permissions and ownership for the master"
# These permissions are required for Passenger to start Puppet as puppet
on master, "chown puppet:puppet #{testdir}/etc/master/config.ru"
on master, "chown -R puppet:puppet #{testdir}/etc/master"

# These permissions are just for testing, end users should protect their
# private keys.
on master, "chmod -R a+rX #{testdir}"

agent_cmd_prefix = "--confdir #{testdir}/etc/agent --vardir #{testdir}/etc/agent/var"
master_cmd_prefix = "--confdir #{testdir}/etc/master --vardir #{testdir}/etc/master/var"

step "Configure EPEL"
epel_release_path = "http://mirror.us.leaseweb.net/epel/6/i386/epel-release-6-8.noarch.rpm"
on master, "rpm -q epel-release || (yum -y install #{epel_release_path} && yum -y upgrade epel-release)"

step "Configure Apache and Passenger"
packages = [ 'httpd', 'mod_ssl', 'mod_passenger', 'rubygem-passenger', 'policycoreutils-python' ]
packages.each do |pkg|
  on master, "rpm -q #{pkg} || (yum -y install #{pkg})"
end

create_remote_file master, "#{testdir}/etc/httpd.conf", fixtures.httpd_conf
on master, 'test -f /etc/httpd/conf/httpd.conf.orig || cp -p /etc/httpd/conf/httpd.conf{,.orig}'
on master, "cat #{testdir}/etc/httpd.conf > /etc/httpd/conf/httpd.conf"

step "Make SELinux and Apache play nicely together..."

# We need this variable in scope.
disable_and_reenable_selinux = 'UNKNOWN'
on master, "sestatus" do
  if stdout.match(/Current mode:.*enforcing/)
    disable_and_reenable_selinux = true
  else
    disable_and_reenable_selinux = false
  end
end

if disable_and_reenable_selinux
  on master, "setenforce 0"
end

step "Start the Apache httpd service..."
on master, 'service httpd restart'

# Move the agent SSL cert and key into place.
# The filename must match the configured certname, otherwise Puppet will try
# and generate a new certificate and key
step "Configure the agent with the externally issued certificates"
on master, "mkdir -p #{testdir}/etc/agent/ssl/{public_keys,certs,certificate_requests,private_keys,private}"
create_remote_file master, "#{testdir}/etc/agent/ssl/certs/#{fixtures.agent_name}.pem", fixtures.agent_cert
create_remote_file master, "#{testdir}/etc/agent/ssl/private_keys/#{fixtures.agent_name}.pem", fixtures.agent_key

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

step "Agent refuses to connect to a rogue master"
on master, puppet_agent("#{agent_cmd_prefix} --ssl_client_ca_auth=#{testdir}/ca_master.crt --masterport=8141 --test"), :acceptable_exit_codes => (0..255) do
  assert_no_match /Creating a new SSL key/, stdout
  assert_match /certificate verify failed/i, stderr
  assert_match /The server presented a SSL certificate chain which does not include a CA listed in the ssl_client_ca_auth file/i, stderr
  assert exit_code == 1
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

step "Cleanup Apache (httpd) and /etc/hosts"
# Restore /etc/hosts
on master, "cp -p '#{testdir}/hosts' /etc/hosts"
# stop the service before moving files around
on master, "/etc/init.d/httpd stop"
on master, "mv --force /etc/httpd/conf/httpd.conf{,.external_ca_test}"
on master, "mv --force /etc/httpd/conf/httpd.conf{.orig,}"

if disable_and_reenable_selinux
  step "Restore the original state of SELinux"
  on master, "setenforce 1"
end

step "Finished testing External Certificates"
