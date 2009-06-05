# A module for keeping track of all the certificates issued by the CA, ever
# Maintains the file "$cadir/inventory.txt"
module Puppet::SSLCertificates
    module Inventory

        # Add CERT to the inventory of issued certs in '$cadir/inventory.txt'
        # If no inventory exists yet, build an inventory and list all the
        # certificates that have been signed so far
        def self.add(cert)
            inited = false
            if FileTest.exists?(Puppet[:cert_inventory])
                inited = true
            end

            Puppet.settings.write(:cert_inventory, "a") do |f|
                f.puts((inited ? nil : self.init).to_s + format(cert))
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

