step "(PUP-4001) Work around packaging issue"
on master, "mkdir -p #{master['distmoduledir']}"
on master, "mkdir -p #{master['sitemoduledir']}"

step "(PUP-4004) Set permissions on puppetserver directories that currently live in the agent cache dir"
%w[reports server_data yaml bucket].each do |dir|
  on master, "install --directory /opt/puppetlabs/puppet/cache/#{dir}"
end
on master, "chown -R puppet:puppet /opt/puppetlabs/puppet/cache"
on master, "chmod -R 750 /opt/puppetlabs/puppet/cache"

# The codedir setting should be passed into the puppetserver
# initialization method, like is done for other required settings
# confdir & vardir. For some reason, puppetserver gets confused
# if this is not done, and tries to manage a directory:
# /opt/puppetlabs/agent/cache/.puppet/code, which is a combination
# of the default master-var-dir in puppetserver, and the user
# based codedir.
step "(SERVER-347) Set required codedir setting on puppetserver"
on master, puppet("config set codedir /etc/puppetlabs/code --section master")

step "(SERVER-370) overwrite ruby-load-path"
create_remote_file(master, '/etc/puppetserver/conf.d/os-settings.conf', <<-EOF)
os-settings: {
    ruby-load-path: [/opt/puppetlabs/puppet/lib/ruby/vendor_ruby]
}
EOF
