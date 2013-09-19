{
  :install => [
    'git://github.com/puppetlabs/facter.git#stable',
    'git://github.com/puppetlabs/hiera.git#stable',
  ],
  :pre_suite => ['setup/git/pre-suite'],
  :ntp => true,
}
