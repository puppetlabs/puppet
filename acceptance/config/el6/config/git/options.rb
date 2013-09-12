{
  :install => [
    'git://github.com/puppetlabs/facter.git#stable',
    'git://github.com/puppetlabs/hiera.git#stable',
    'git://github.com/puppetlabs/puppet.git#master',
  ],
  :pre_suite => ['setup/git/pre-suite'],
  :ntp => true,
}
