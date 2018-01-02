require 'puppet/util/feature'

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
Puppet.features.add(:microsoft_windows) do
  begin
    # ruby
    require 'Win32API' # case matters in this require!

    # Note: Setting codepage here globally ensures all strings returned via
    # WIN32OLE (Ruby's late-bound COM support) are encoded in Encoding::UTF_8
    #
    # Also, this does not modify the value of WIN32OLE.locale - which defaults
    # to 2048 (at least on US English Windows) and is not listed in the MS
    # locales table, here: https://msdn.microsoft.com/en-us/library/ms912047(v=winembedded.10).aspx
    require 'win32ole' ; WIN32OLE.codepage = WIN32OLE::CP_UTF8
    # gems
    require 'win32/process'
    require 'win32/dir'
    require 'win32/service'
    true
  rescue LoadError => err
    #TRANSLATORS "win32-process", "win32-dir", and "win32-service" are program names and should not be translated
    warn _("Cannot run on Microsoft Windows without the win32-process, win32-dir and win32-service gems: %{err}") % { err: err } unless Puppet.features.posix?
  end
end

raise Puppet::Error,_("Cannot determine basic system flavour") unless Puppet.features.posix? or Puppet.features.microsoft_windows?

# We've got LDAP available.
Puppet.features.add(:ldap, :libs => ["ldap"])

# We have the Rdoc::Usage library.
Puppet.features.add(:usage, :libs => %w{rdoc/ri/ri_paths rdoc/usage})

# We have libshadow, useful for managing passwords.
Puppet.features.add(:libshadow, :libs => ["shadow"])

# We're running as root.
Puppet.features.add(:root) { require 'puppet/util/suidmanager'; Puppet::Util::SUIDManager.root? }

# We have lcs diff
Puppet.features.add :diff, :libs => %w{diff/lcs diff/lcs/hunk}

# We have augeas
Puppet.features.add(:augeas, :libs => ["augeas"])

# We have OpenSSL
Puppet.features.add(:openssl, :libs => ["openssl"])

# We have sqlite
Puppet.features.add(:sqlite, :libs => ["sqlite3"])

# We have Hiera
Puppet.features.add(:hiera, :libs => ["hiera"])

Puppet.features.add(:minitar, :libs => ["archive/tar/minitar"])

# We can manage symlinks
Puppet.features.add(:manages_symlinks) do
  if ! Puppet::Util::Platform.windows?
    true
  else
    module WindowsSymlink
      require 'ffi'
      extend FFI::Library

      def self.is_implemented
        begin
          ffi_lib :kernel32
          attach_function :CreateSymbolicLinkW, [:lpwstr, :lpwstr, :dword], :boolean

          true
        rescue LoadError
          Puppet.debug("CreateSymbolicLink is not available")
          false
        end
      end
    end

    WindowsSymlink.is_implemented
  end
end
