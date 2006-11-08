# A module for keeping track of all the certificates issued by the CA, ever
# Maintains the file "$cadir/inventory.txt"
module Puppet::SSLCertificates
    module Inventory

        Puppet.config.setdefaults(:ca,
            :cert_inventory => {
                :default => "$cadir/inventory.txt",
                :mode => 0644,
                :owner => "$user",
                :group => "$group",
                :desc => "A Complete listing of all certificates"
            }
        )

        # Add CERT to the inventory of issued certs in '$cadir/inventory.txt'
        # If no inventory exists yet, build an inventory and list all the 
        # certificates that have been signed so far
        def self.add(cert)
            unless FileTest.exists?(Puppet[:cert_inventory])
                inited = false
            end

            Puppet.config.write(:cert_inventory, "a") do |f|
                unless inited
                    f.puts self.init
                end
                f.puts format(cert)
            end
        end

        private

        def self.init
            inv = "# Inventory of signed certificates\n"
            inv += "# SERIAL NOT_BEFORE NOT_AFTER SUBJECT\n"
            Dir.glob(File::join(Puppet[:signeddir], "*.pem")) do |f|
                inv += format(OpenSSL::X509::Certificate.new(File::read(f))) + "\n"
            end
            return inv
        end

        def self.format(cert)
            iso = '%Y-%m-%dT%H:%M:%S%Z'
            return "0x%04x %s %s %s" % [cert.serial,  
                                        cert.not_before.strftime(iso), 
                                        cert.not_after.strftime(iso),
                                        cert.subject]
        end
    end
end

# $Id$
