module Puppet::Util::Libuser
   def self.getconf
     File.expand_path("../libuser.conf", __FILE__)
   end

   def self.getenv
     newenv = {}
     newenv['LIBUSER_CONF'] = getconf
     newenv
   end

end
