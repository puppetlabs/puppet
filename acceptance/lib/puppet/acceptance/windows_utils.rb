require 'puppet/acceptance/common_utils'

module Puppet
  module Acceptance
    module WindowsUtils
      require 'puppet/acceptance/windows_utils/service.rb'
      require 'puppet/acceptance/windows_utils/package_installer.rb'

      def profile_base(agent)
        ruby = Puppet::Acceptance::CommandUtils.ruby_command(agent)
        getbasedir = <<'END'
require 'win32/dir'
puts Dir::PROFILE.match(/(.*)\\\\[^\\\\]*/)[1]
END
        on(agent, "#{ruby} -e \"#{getbasedir}\"").stdout.chomp
      end

      # Checks whether the account with the given username has the given password on a host
      def assert_password_matches_on(host, username, password, msg = nil)
        script = <<-PS1
  Add-Type -AssemblyName System.DirectoryServices.AccountManagement
  $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine, $env:COMPUTERNAME)
  $ctx.ValidateCredentials("#{username}", "#{password}")
        PS1
        execute_powershell_script_on(host, script) do |result|
          assert_match(/True/, result.stdout.strip, msg)
        end
      end

      def current_attributes_on(host, user)
        retrieve_user_attributes = <<-PS1
function Is-UserFlagSet($user, $flag) {
  # Only declare the flags we need. More can be added as we add
  # more attributes to the Windows user.
  $ADS_USERFLAGS = @{
    'ADS_UF_ACCOUNTDISABLE'     = 0x0002;
    'ADS_UF_PASSWD_CANT_CHANGE' = 0x0040;
    'ADS_UF_DONT_EXPIRE_PASSWD' = 0x10000
  }

  $flag_set = ($user.get('UserFlags') -band $ADS_USERFLAGS[$flag]) -ne 0

  # 'true' and 'false' are 'True' and 'False' in Powershell, respectively,
  # so we need to convert them from their Powershell representation to their
  # Ruby one.
  "'$(([string] $flag_set).ToLower())'"
}

# This lets us fail the test if an error occurs while running
# the script.
$ErrorActionPreference = 'Stop'

$user = [ADSI]"WinNT://./#{user},user"
$attributes = @{
  'full_name'                   = "'$($user.FullName)'";
  'password_change_required'    = If ($user.PasswordExpired -eq 1) { "'true'" } Else { "'false'" };
  'disabled'                    = Is-UserFlagSet $user 'ADS_UF_ACCOUNTDISABLE';
  'password_change_not_allowed' = Is-UserFlagSet $user 'ADS_UF_PASSWD_CANT_CHANGE';
  'password_never_expires'      = Is-UserFlagSet $user 'ADS_UF_DONT_EXPIRE_PASSWD';
}

Write-Output "{"
foreach ($attribute in $attributes.keys) {
  Write-Output "  '${attribute}' => $($attributes[$attribute]),"
}
Write-Output "}"
  PS1

        stdout = execute_powershell_script_on(host, retrieve_user_attributes).stdout.chomp
        Kernel.eval(stdout)
      end
    end
  end
end
