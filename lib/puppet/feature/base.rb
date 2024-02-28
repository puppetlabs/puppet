# frozen_string_literal: true

require_relative '../../puppet/util/feature'

# Add the simple features, all in one file.

# Order is important as some features depend on others

# We have a syslog implementation
Puppet.features.add(:syslog, :libs => ["syslog"])

# We can use POSIX user functions
Puppet.features.add(:posix) do
  require 'etc'
  !Etc.getpwuid(0).nil? && Puppet.features.syslog?
end

# We can use Microsoft Windows functions
Puppet.features.add(:microsoft_windows) { Puppet::Util::Platform.windows? }

raise Puppet::Error, _("Cannot determine basic system flavour") unless Puppet.features.posix? or Puppet.features.microsoft_windows?

# We've got LDAP available.
Puppet.features.add(:ldap, :libs => ["ldap"])

# We have the Rdoc::Usage library.
Puppet.features.add(:usage, :libs => %w[rdoc/ri/ri_paths rdoc/usage])

# We have libshadow, useful for managing passwords.
Puppet.features.add(:libshadow, :libs => ["shadow"])

# We're running as root.
Puppet.features.add(:root) do
  require_relative '../../puppet/util/suidmanager'
  Puppet::Util::SUIDManager.root?
end

# We have lcs diff
Puppet.features.add :diff, :libs => %w[diff/lcs diff/lcs/hunk]

# We have OpenSSL
Puppet.features.add(:openssl, :libs => ["openssl"])

# We have sqlite
Puppet.features.add(:sqlite, :libs => ["sqlite3"])

# We have Hiera
Puppet.features.add(:hiera, :libs => ["hiera"])

Puppet.features.add(:minitar, :libs => ["archive/tar/minitar"])

# We can manage symlinks
Puppet.features.add(:manages_symlinks) do
  if !Puppet::Util::Platform.windows?
    true
  else
    module WindowsSymlink
      require 'ffi'
      extend FFI::Library

      def self.is_implemented # rubocop:disable Naming/PredicateName
        begin
          ffi_lib :kernel32
          attach_function :CreateSymbolicLinkW, [:lpwstr, :lpwstr, :dword], :boolean

          true
        rescue LoadError
          Puppet.debug { "CreateSymbolicLink is not available" }
          false
        end
      end
    end

    WindowsSymlink.is_implemented
  end
end

Puppet.features.add(:puppetserver_ca, libs: ['puppetserver/ca', 'puppetserver/ca/action/clean'])
