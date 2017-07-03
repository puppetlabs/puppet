test_name "Augeas puppet configuration" do

  tag 'risk:medium',
      'audit:medium',
      'audit:acceptance'

  skip_test 'requires augeas which is included in AIO' if @options[:type] != 'aio'

  confine :except, :platform => 'windows'
  confine :to, {}, hosts.select { |host| ! host[:roles].include?('master') }

  teardown do
    hosts.each do |host|
      on host, "cat /tmp/puppet.conf.bak > #{host.puppet['confdir']}/puppet.conf && rm /tmp/puppet.conf.bak"
    end
  end

  hosts.each do |host|
    step "Backup the puppet config" do
    on host, "mv #{host.puppet['confdir']}/puppet.conf /tmp/puppet.conf.bak"
    end
    step "Create a new puppet config that has a master and agent section" do
      puppet_conf = <<-CONF
      [main]
      CONF
    on(host, "echo \"#{puppet_conf}\" >> #{host.puppet['confdir']}/puppet.conf")
    on(host, "puppet config set runinterval 10 --section agent")
    end

    step "Modify the puppet.conf file"
    manifest = <<EOF
  augeas { 'puppet agent noop mode':
    context => "/files#{host.puppet['confdir']}/puppet.conf/agent",
    incl    => "/etc/puppetlabs/puppet/puppet.conf",
    lens    => 'Puppet.lns',
    changes => 'set noop true',
  }
EOF
    on host, puppet_apply('--verbose'), :stdin => manifest

    on host, "grep 'noop=true' #{host.puppet['confdir']}/puppet.conf"
  end
end
