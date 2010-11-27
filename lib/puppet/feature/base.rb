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
Puppet.features.add(:rrd_legacy, :libs => ["RRDtool"])
Puppet.features.add(:rrd, :libs => ["RRD"])

# We have OpenSSL
Puppet.features.add(:openssl, :libs => ["openssl"])

# We have a syslog implementation
Puppet.features.add(:syslog, :libs => ["syslog"])

# We can use POSIX user functions
Puppet.features.add(:posix) do
  require 'etc'
  Etc.getpwuid(0) != nil && Puppet.features.syslog?
end

# We can use Microsoft Windows functions
Puppet.features.add(:microsoft_windows, :libs => ["sys/admin", "win32/process", "win32/dir"])

raise Puppet::Error,"Cannot determine basic system flavour" unless Puppet.features.posix? or Puppet.features.microsoft_windows?

# We have CouchDB
Puppet.features.add(:couchdb, :libs => ["couchrest"])

# We have sqlite
Puppet.features.add(:sqlite, :libs => ["sqlite3"])
