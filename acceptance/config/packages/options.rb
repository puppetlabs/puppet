{
  :type => 'foss-packages',
  :pre_suite => [
    'setup/packages/pre-suite/010_Install.rb',
    'setup/packages/pre-suite/015_PackageHostsPresets.rb',
    'setup/common/pre-suite/025_StopFirewall.rb',
    'setup/common/pre-suite/040_ValidateSignCert.rb',
    'setup/packages/pre-suite/045_EnsureMasterStartedOnPassenger.rb',
    'setup/common/pre-suite/070_InstallCACerts.rb',
  ],
}
