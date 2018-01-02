test_name "Augeas puppet configuration" do

  tag 'risk:medium',
      'audit:medium',
      'audit:acceptance',
      'audit:refactor'      # move to types test dir

  skip_test 'requires augeas which is included in AIO' if @options[:type] != 'aio'

  confine :except, :platform => 'windows'
  confine :to, {}, hosts.select { |host| ! host[:roles].include?('master') }

  teardown do
    agents.each do |agent|
      on agent, "cat /tmp/puppet.conf.bak > #{agent.puppet['confdir']}/puppet.conf && rm /tmp/puppet.conf.bak"
    end
  end

  agents.each do |agent|
    step "Backup the puppet config" do
      on agent, "mv #{agent.puppet['confdir']}/puppet.conf /tmp/puppet.conf.bak"
    end
    step "Create a new puppet config that has a master and agent section" do
      puppet_conf = <<-CONF
      [main]
      CONF
      on agent, "echo \"#{puppet_conf}\" >> #{agent.puppet['confdir']}/puppet.conf"
    end

    step "Modify the puppet.conf file" do
      manifest = <<-EOF
      augeas { 'puppet agent noop mode':
        context => "/files#{agent.puppet['confdir']}/puppet.conf/agent",
        incl    => "/etc/puppetlabs/puppet/puppet.conf",
        lens    => 'Puppet.lns',
        changes => 'set noop true',
      }
      EOF
      on agent, puppet_apply('--verbose'), :stdin => manifest

      on agent, "grep 'noop=true' #{agent.puppet['confdir']}/puppet.conf"
    end

  end

end
