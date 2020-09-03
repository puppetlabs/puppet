require 'puppet/acceptance/common_utils'

module Puppet
  module Acceptance
    module WindowsUtils
      require 'puppet/acceptance/windows_utils/service.rb'
      require 'puppet/acceptance/windows_utils/package_installer.rb'

      def profile_base(agent)
        ruby = Puppet::Acceptance::CommandUtils.ruby_command(agent)
        getbasedir = <<'END'
puts ENV['USERPROFILE'].match(/(.*)\\\\[^\\\\]*/)[1]
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
        result = execute_powershell_script_on(host, script) 
        assert_match(/True/, result.stdout.strip, msg)
      end

      def deny_administrator_access_to(host, filepath)
        # we need to create a fake directory in the user's tempdir with powershell because the ACL
        # perms set down by cygwin when making tempdirs makes the ACL unusable. Thus we create a
        # tempdir using powershell and pull its' ACL as a starting point for the new ACL.
        script = <<-PS1
  mkdir -Force $env:TMP\\fake-dir-for-acl
  $acl = Get-ACL $env:TMP\\fake-dir-for-acl
  rm -Force $env:TMP\\fake-dir-for-acl
  $ar = New-Object system.security.accesscontrol.filesystemaccessrule("Administrator","FullControl","Deny")
  $acl.SetAccessRule($ar)
  Set-ACL #{filepath} $acl
        PS1
        execute_powershell_script_on(host, script)
      end
    end
  end
end
