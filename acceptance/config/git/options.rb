{
  :type                        => :git,
  :install                     => [
    'puppet',
  ],
  :pre_suite                   => [
    'setup/common/pre-suite/000-delete-puppet-when-none.rb',
    'setup/git/pre-suite/000_EnvSetup.rb',
    'setup/git/pre-suite/010_TestSetup.rb',
    'setup/git/pre-suite/020_PuppetUserAndGroup.rb',
    'setup/common/pre-suite/025_StopFirewall.rb',
    'setup/git/pre-suite/030_PuppetMasterSanity.rb',
    'setup/common/pre-suite/040_ValidateSignCert.rb',
    'setup/git/pre-suite/060_InstallModules.rb',
    'setup/git/pre-suite/070_InstallCACerts.rb',
  ],
}
