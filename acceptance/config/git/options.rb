{
  :install => [
    'facter#stable',
    'hiera#stable',
    'puppet',
  ],
  :pre_suite => [
    'setup/git/pre-suite/000_EnvSetup.rb',
    'setup/git/pre-suite/010_TestSetup.rb',
    'setup/git/pre-suite/020_PuppetUserAndGroup.rb',
    'setup/common/pre-suite/025_StopFirewall.rb',
    'setup/git/pre-suite/030_PuppetMasterSanity.rb',
    'setup/common/pre-suite/040_ValidateSignCert.rb',
    'setup/git/pre-suite/060_InstallModules.rb',
    'setup/git/pre-suite/070_InstalCACerts.rb',
    'setup/common/pre-suite/100_SetParser.rb',
  ],
}
