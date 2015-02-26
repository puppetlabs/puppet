step "(PUP-4001) Work around packaging issue"
on master, "mkdir -p #{master['distmoduledir']}"
on master, "mkdir -p #{master['sitemoduledir']}"

step "(PUP-4004) Set permissions on puppetserver directories that currently live in the agent cache dir"
%w[reports server_data yaml bucket].each do |dir|
  on master, "install --directory /opt/puppetlabs/puppet/cache/#{dir}"
end
on master, "chown -R puppet:puppet /opt/puppetlabs/puppet/cache"
on master, "chmod -R 750 /opt/puppetlabs/puppet/cache"

# The AIO puppet-agent package does not create the puppet user or group, but
# puppet-server does. However, some puppet acceptance tests assume the user
# is present. This is a temporary setup step to create the puppet user and
# group, but only on nodes that are agents and not the master
test_name '(PUP-3997) Puppet User and Group on agents only' do
  agents.each do |agent|
    if agent == master
      step "Skipping creating puppet user and group on #{agent}"
    else
      step "Ensure puppet user and group added to #{agent}" do
        on agent, puppet("resource user puppet ensure=present")
        on agent, puppet("resource group puppet ensure=present")
      end
    end
  end
end

# The codedir setting should be passed into the puppetserver
# initialization method, like is done for other required settings
# confdir & vardir. For some reason, puppetserver gets confused
# if this is not done, and tries to manage a directory:
# /opt/puppetlabs/agent/cache/.puppet/code, which is a combination
# of the default master-var-dir in puppetserver, and the user
# based codedir.
step "(SERVER-347) Set required codedir setting on puppetserver"
on master, puppet("config set codedir /etc/puppetlabs/code --section master")

