require 'puppet/ssl'
require 'puppet/ssl/certificate'

# Keep track of all of our known certificates.
class Puppet::SSL::Inventory
  attr_reader :path

  # Add a certificate to our inventory.
  def add(cert)
    cert = cert.content if cert.is_a?(Puppet::SSL::Certificate)
    Puppet.settings.setting(:cert_inventory).open("a") do |f|
      f.print format(cert)
    end
  end

  # Format our certificate for output.
  def format(cert)
    iso = '%Y-%m-%dT%H:%M:%S%Z'
    "0x%04x %s %s %s\n" % [cert.serial,  cert.not_before.strftime(iso), cert.not_after.strftime(iso), cert.subject]
  end

  def initialize
    @path = Puppet[:cert_inventory]
  end

  # Rebuild the inventory from scratch.  This should happen if
  # the file is entirely missing or if it's somehow corrupted.
  def rebuild
    Puppet.notice "Rebuilding inventory file"

    Puppet.settings.setting(:cert_inventory).open('w') do |f|
      Puppet::SSL::Certificate.indirection.search("*").each do |cert|
        f.print format(cert.content)
      end
    end
  end

  # Find the serial number for a given certificate.
  def serial(name)
    return nil unless Puppet::FileSystem::File.exist?(@path)

    File.readlines(@path).each do |line|
      next unless line =~ /^(\S+).+\/CN=#{name}$/

      return Integer($1)
    end

    return nil
  end
end
