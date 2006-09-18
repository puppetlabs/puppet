# A module for keeping track of all the certificates issued by the CA, ever
# Maintains the file "$cadir/inventory.txt"
module Puppet::SSLCertificates
    module Inventory

        # Add CERT to the inventory of issued certs in '$cadir/inventory.txt'
        # If no inventory exists yet, build an inventory and list all the 
        # certificates that have been signed so far
        def Inventory.add(cert)
            f = open
            format(f, cert)
            f.close()
        end

        def Inventory.filename
            File::join(Puppet[:cadir], "inventory.txt")
        end

        private
        def Inventory.open
            if File::exist?(filename)
                File::open(filename, "a")
            else
                init
            end
        end

        def Inventory.init
            if File::exist?(filename)
                raise Puppet::Error, 
                "Inventory file #{filename} already exists"
            end
            inv = File.open(filename, "w")
            inv.puts "# Inventory of signed certificates"
            inv.puts "# SERIAL NOT_BEFORE _NOT_AFTER SUBJECT"
            Dir.glob(File::join(Puppet[:signeddir], "*.pem")) do |f|
                format(inv, OpenSSL::X509::Certificate.new(File::read(f)))
            end
            return inv
        end

        def Inventory.format(f, cert)
            iso = '%Y-%m-%dT%H:%M:%S%Z'
            f.puts "0x%04x %s %s %s" % [cert.serial,  
                                        cert.not_before.strftime(iso), 
                                        cert.not_after.strftime(iso),
                                        cert.subject]
        end
    end
end
