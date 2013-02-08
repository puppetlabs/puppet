module Puppet::Util::Libuser
   def self.getconf
     File.join(Puppet.settings[:confdir], "provider", "libuser.conf")
   end

   def self.getenv
     newenv = {}
     newenv['LIBUSER_CONF'] = getconf
     newenv
   end

end
