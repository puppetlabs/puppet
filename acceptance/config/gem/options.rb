{
  # Use `git` so that we have a sane ruby environment
  :type => 'git',
  :pre_suite => [
    'setup/common/pre-suite/000-delete-puppet-when-none.rb',
    'setup/git/pre-suite/000_EnvSetup.rb',
  ],
}
