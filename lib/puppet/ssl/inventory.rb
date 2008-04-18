require 'puppet/ssl'
require 'puppet/ssl/certificate'

# Manage private and public keys as a pair.
class Puppet::SSL::Inventory
    attr_reader :path

    # Add a certificate to our inventory.
    def add(cert)
        Puppet.settings.write(:cert_inventory, "a") do |f|
            f.print format(cert)
        end
    end

    # Format our certificate for output.
    def format(cert)
        iso = '%Y-%m-%dT%H:%M:%S%Z'
        return "0x%04x %s %s %s" % [cert.serial,  cert.not_before.strftime(iso), cert.not_after.strftime(iso), cert.subject]
    end

    def initialize
        @path = Puppet[:cert_inventory]

        rebuild unless FileTest.exist?(@path)
    end

    # Rebuild the inventory from scratch.  This should happen if
    # the file is entirely missing or if it's somehow corrupted.
    def rebuild
        Puppet.notice "Rebuilding inventory file"

        Puppet.settings.write(:cert_inventory) do |f|
            f.print "# Inventory of signed certificates\n# SERIAL NOT_BEFORE NOT_AFTER SUBJECT\n"
        end

        Puppet::SSL::Certificate.search("*").each { |cert| add(cert) }
    end
end
