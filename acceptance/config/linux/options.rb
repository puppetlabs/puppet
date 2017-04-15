{
  :config => 'config.yaml',
  :type => 'git',
  :helper => '../../lib/helper.rb',
  :install => [
    'git://github.com/puppetlabs/facter.git#1.6.x',
    'git://github.com/puppetlabs/hiera.git#1.x',
    'git://github.com/puppetlabs/puppet.git#stable'
  ],
  :debug => true,
  :keyfile => "acceptance.priv"
}
