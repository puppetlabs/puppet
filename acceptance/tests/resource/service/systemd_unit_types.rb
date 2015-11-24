test_name 'Systemd provider should recognize non-service unit types'

confine :to, :platform => /fedora-22/

# This test is intended to ensure that systemd unit types other than service are
# also discoverable via puppet. Examples include timer and socket units.

agents.each do |agent|
  teardown do
    on(agent, puppet_resource('package', 'dnf-automatic', 'ensure=purged'))
    on(agent, puppet_resource('package', 'httpd', 'ensure=purged'))
  end

  step "#{agent}: Install dnf-automatic and httpd packages"
  on(agent, puppet_resource('package', 'dnf-automatic', 'ensure=installed'))
  on(agent, puppet_resource('package', 'httpd', 'ensure=installed'))

  step "#{agent}: Ensure the dnf-automatic timer unit and httpd socket unit are known by puppet"
  on(agent, puppet_resource('service')) do
    assert_match(/dnf-automatic\.timer/, stdout, 'Puppet did not detect the dnf-automatic systemd timer unit')
    assert_match(/httpd\.socket/, stdout, 'Puppet did not detect the httpd systemd socket unit')
  end
end
