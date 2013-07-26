{
  :config => './config/local/config.yaml',
  :install => [
    'git://github.com/puppetlabs/facter.git#stable',
    'git://github.com/puppetlabs/hiera.git#stable',
    'git://github.com/puppetlabs/puppet.git#stable'
  ],
  :pre_suite => ['setup/local'],
  :keyfile => "acceptance.priv",
}
