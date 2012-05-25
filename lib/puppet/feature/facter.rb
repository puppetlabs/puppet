require 'puppet/util/feature'
require 'semver'

# See if Facter is available, and check revision
Puppet.features.add(:facter) do
  required_facter = "2.0.0"

  begin
    require 'facter'
  rescue LoadError => err
    begin
      require 'rubygems'
      require 'facter'
    rescue LoadError => err
    end
  end

  raise Puppet::Error, "Cannot find Facter class. Facter may not be installed, " +
      "or not be in your RUBYLIB." unless defined?(::Facter)
  raise Puppet::Error, "Cannot find Facter version declaration. Your " +
        "installation of Facter may be invalid, very old or this may be a bug." unless defined?(::Facter.version)
    
  facter_version = ::SemVer.new(::Facter.version)
  required_version = ::SemVer.new(required_facter)
  raise Puppet::Error, "Found Facter version #{::Facter.version} " +
       "however version #{required_facter} (or greater) is required for " +
       "Puppet to operate" unless facter_version >= required_version
       
  true
end