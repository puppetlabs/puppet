step "(PUP-4001) Work around packaging issue"
on master, "mkdir -p #{master['distmoduledir']}"
on master, "mkdir -p #{master['sitemoduledir']}"

step "(PUP-4004) Set permissions on puppetserver directories that currently live in the agent cache dir"
%w[reports server_data yaml bucket].each do |dir|
  on master, "install --directory /opt/puppetlabs/puppet/cache/#{dir}"
end
on master, "chown -R puppet:puppet /opt/puppetlabs/puppet/cache"
on master, "chmod -R 750 /opt/puppetlabs/puppet/cache"
