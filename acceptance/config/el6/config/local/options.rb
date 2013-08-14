{
  :config => './config/local/config.yaml',
  :install => [
    'git://github.com/puppetlabs/facter.git#stable',
    'git://github.com/puppetlabs/hiera.git#stable',
    'file:///vagrant-puppet',
  ],
  :pre_suite => ['setup/local'],
  :keyfile => "acceptance.priv",
}
