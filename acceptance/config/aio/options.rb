{
  :type => 'aio',
  :pre_suite => [
    'setup/common/pre-suite/001_PkgBuildSetup.rb',
    'setup/aio/pre-suite/010_Install.rb',
    'setup/aio/pre-suite/015_PackageHostsPresets.rb',
    'setup/common/pre-suite/025_StopFirewall.rb',
    'setup/common/pre-suite/040_ValidateSignCert.rb',
    'setup/aio/pre-suite/045_EnsureMasterStartedOnPassenger.rb',
    'setup/common/pre-suite/070_InstallCACerts.rb',
  ],
}
