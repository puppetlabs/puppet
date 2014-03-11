{
  :pre_suite => [
    'setup/packages/pre-suite/010_Install.rb',
    'setup/common/pre-suite/025_StopFirewall.rb',
    'setup/common/pre-suite/040_ValidateSignCert.rb',
    'setup/common/pre-suite/100_SetParser.rb',
  ],
}
