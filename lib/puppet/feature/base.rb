#  Created by Luke Kanies on 2006-04-30.
#  Copyright (c) 2006. All rights reserved.

require 'puppet/util/feature'

# Add the simple features, all in one file.

# We've got LDAP available.
Puppet.features.add(:ldap, :libs => ["ldap"])

# We have the Rdoc::Usage library.
Puppet.features.add(:usage, :libs => %w{rdoc/ri/ri_paths rdoc/usage})

# We have libshadow, useful for managing passwords.
Puppet.features.add(:libshadow, :libs => ["shadow"])

# We're running as root.
Puppet.features.add(:root) { require 'puppet/util/suidmanager'; Puppet::Util::SUIDManager.root? }

# We've got mongrel available
Puppet.features.add(:mongrel, :libs => %w{rubygems mongrel puppet/network/http_server/mongrel})

# We have lcs diff
Puppet.features.add :diff, :libs => %w{diff/lcs diff/lcs/hunk}

# We have augeas
Puppet.features.add(:augeas, :libs => ["augeas"])

# We have RRD available
Puppet.features.add(:rrd, :libs => ["RRDtool"])

# We have OpenSSL
Puppet.features.add(:openssl, :libs => ["openssl"])

# We can use POSIX user functions? The require returns false on Windows
Puppet.features.add(:posix) do
    require 'etc'
    Etc.getpwuid(0) != nil
end

# We can use Win32 functions
Puppet.features.add(:win32, :libs => ["sys/admin", "win32/process"])

raise Puppet::Error "Cannot determine basic system flavour" unless Puppet.features.posix? or Puppet.features.win32?
