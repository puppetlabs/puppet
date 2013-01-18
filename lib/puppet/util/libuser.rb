module Puppet::Util::Libuser
   def self.getconf
     File.expand_path("../../feature/libuser.conf", __FILE__)
   end

   def self.setupenv
     ENV['LIBUSER_CONF'] = getconf
   end
end
