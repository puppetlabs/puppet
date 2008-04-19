require 'puppet/ssl'
require 'puppet/ssl/certificate'

# Keep track of all of our known certificates.
class Puppet::SSL::Inventory
    attr_reader :path

    # Add a certificate to our inventory.
    def add(cert)
        cert = cert.content if cert.is_a?(Puppet::SSL::Certificate)

        # Create our file, if one does not already exist.
        rebuild unless FileTest.exist?(@path)

        Puppet.settings.write(:cert_inventory, "a") do |f|
            f.print format(cert)
        end
    end

    # Format our certificate for output.
    def format(cert)
        iso = '%Y-%m-%dT%H:%M:%S%Z'
        return "0x%04x %s %s %s\n" % [cert.serial,  cert.not_before.strftime(iso), cert.not_after.strftime(iso), cert.subject]
    end

    def initialize
        @path = Puppet[:cert_inventory]
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

    # Find the serial number for a given certificate.
    def serial(name)
        return nil unless FileTest.exist?(@path)

        File.readlines(@path).each do |line|
            next unless line =~ /^(\S+).+\/CN=#{name}$/

            return Integer($1)
        end
    end
end
