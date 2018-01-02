test_name "Augeas services file" do

  tag 'risk:medium',
      'audit:medium',
      'audit:acceptance',
      'audit:refactor'      # move to types test dir
                            # use single manifest/apply

  skip_test 'requires augeas which is included in AIO' if @options[:type] != 'aio'

  confine :except, :platform => 'windows'
  confine :except, :platform => 'osx'
  confine :to, {}, hosts.select { |host| ! host[:roles].include?('master') }

  step "Backup the services file" do
    on hosts, "cp /etc/services /tmp/services.bak"
  end

  begin
    step "Add an entry to the services file" do
      manifest = <<EOF
augeas { 'add_services_entry':
  context => '/files/etc/services',
  incl    => '/etc/services',
  lens    => 'Services.lns',
  changes => [
    'ins service-name after service-name[last()]',
    'set service-name[last()] "Doom"',
    'set service-name[. = "Doom"]/port "666"',
    'set service-name[. = "Doom"]/protocol "udp"'
  ]
}
EOF

      on hosts, puppet_apply('--verbose'), :stdin => manifest
      on hosts, "fgrep 'Doom 666/udp' /etc/services"
    end

    step "Change the protocol to udp" do
      manifest = <<EOF
augeas { 'change_service_protocol':
  context => '/files/etc/services',
  incl    => '/etc/services',
  lens    => 'Services.lns',
  changes => [
    'set service-name[. = "Doom"]/protocol "tcp"'
  ]
}
EOF

      on hosts, puppet_apply('--verbose'), :stdin => manifest
      on hosts, "fgrep 'Doom 666/tcp' /etc/services"
    end

    step "Remove the services entry" do
      manifest = <<EOF
augeas { 'del_service_entry':
  context => '/files/etc/services',
  incl    => '/etc/services',
  lens    => 'Services.lns',
  changes => [
    'rm service-name[. = "Doom"]'
  ]
}
EOF

      on hosts, puppet_apply('--verbose'), :stdin => manifest
      on hosts, "fgrep 'Doom 666/tcp' /etc/services", :acceptable_exit_codes => [1]
    end
  ensure
    on hosts, "mv /tmp/services.bak /etc/services"
  end
end
