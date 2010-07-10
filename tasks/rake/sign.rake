desc "Sign to the package with the Puppet Labs release key"
task :sign_packages do

version = Puppet::PUPPETVERSION

# Sign package

sh "gpg --homedir $HOME/pl_release_key --detach-sign --output pkg/puppet-#{version}.tar.gz.sign --armor pkg/puppet-#{version}.tar.gz"

# Sign gem

sh "gpg --homedir $HOME/pl_release_key --detach-sign --output pkg/puppet-#{version}.gem.sign --armor pkg/puppet-#{version}.gem"

end
