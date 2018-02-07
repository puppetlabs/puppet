{
  :type => 'git',
  :install => [
  ],
  :pre_suite => [
    'setup/common/pre-suite/000-delete-puppet-when-none.rb',
    'setup/git/pre-suite/000_EnvSetup.rb',
  ],
}.merge(eval File.read('config/common/options.rb'))
