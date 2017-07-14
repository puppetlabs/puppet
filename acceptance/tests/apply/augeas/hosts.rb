test_name "Augeas hosts file" do

tag 'risk:medium',
    'audit:medium',
    'audit:acceptance',
    'audit:refactor' # move to puppet types test directory, this is not testing puppet apply
                     # reduce to a single manifest and apply

skip_test 'requires augeas which is included in AIO' if @options[:type] != 'aio'

  confine :except, :platform => [
    'windows',
    'cisco_ios',   # PUP-7380
  ]
  confine :to, {}, hosts.select { |host| ! host[:roles].include?('master') }

  step "Backup the hosts file" do
    on hosts, 'cp /etc/hosts /tmp/hosts.bak'
  end

  # We have a begin/ensure block here to clean up the hosts file in case
  # of test failure.
  begin

    step "Create an entry in the hosts file" do
      manifest = <<EOF
augeas { 'add_hosts_entry':
  context => '/files/etc/hosts',
  incl    => '/etc/hosts',
  lens    => 'Hosts.lns',
  changes => [
    'set 01/ipaddr 192.168.0.1',
    'set 01/canonical pigiron.example.com',
    'set 01/alias[1] pigiron',
    'set 01/alias[2] piggy'
  ]
}
EOF
      on hosts, puppet_apply('--verbose'), :stdin => manifest
      on hosts, "fgrep '192.168.0.1\tpigiron.example.com pigiron piggy' /etc/hosts"
    end

    step "Modify an entry in the hosts file" do
      manifest = <<EOF
augeas { 'mod_hosts_entry':
  context => '/files/etc/hosts',
  incl    => '/etc/hosts',
  lens    => 'Hosts.lns',
  changes => [
    'set *[canonical = "pigiron.example.com"]/alias[last()+1] oinker'
  ]
}
EOF

      on hosts, puppet_apply('--verbose'), :stdin => manifest
      on hosts, "fgrep '192.168.0.1\tpigiron.example.com pigiron piggy oinker' /etc/hosts"
    end

    step "Remove an entry from the hosts file" do
      manifest = <<EOF
augeas { 'del_hosts_entry':
  context => '/files/etc/hosts',
  incl    => '/etc/hosts',
  lens    => 'Hosts.lns',
  changes => [
    'rm *[canonical = "pigiron.example.com"]'
  ]
}
EOF

      on hosts, puppet_apply('--verbose'), :stdin => manifest
      on hosts, "fgrep 'pigiron.example.com' /etc/hosts", :acceptable_exit_codes => [1]
    end

  ensure
    on hosts, 'cat /tmp/hosts.bak > /etc/hosts && rm /tmp/hosts.bak'
  end
end
