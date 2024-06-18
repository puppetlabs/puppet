# frozen_string_literal: true

class Puppet::Node::ServerFacts
  def self.load
    server_facts = {}

    # Add our server Puppet Enterprise version, if available.
    pe_version_file = '/opt/puppetlabs/server/pe_version'
    if File.readable?(pe_version_file) and !File.zero?(pe_version_file)
      server_facts['pe_serverversion'] = File.read(pe_version_file).chomp
    end

    # Add our server version to the fact list
    server_facts["serverversion"] = Puppet.version.to_s

    # And then add the server name and IP
    {"servername" => "fqdn",
      "serverip"  => "ipaddress",
      "serverip6" => "ipaddress6"}.each do |var, fact|
      value = Puppet.runtime[:facter].value(fact)
      if !value.nil?
        server_facts[var] = value
      end
    end

    if server_facts["servername"].nil?
      host = Puppet.runtime[:facter].value(:hostname)
      if host.nil?
        Puppet.warning _("Could not retrieve fact servername")
      elsif domain = Puppet.runtime[:facter].value(:domain) #rubocop:disable Lint/AssignmentInCondition
        server_facts["servername"] = [host, domain].join(".")
      else
        server_facts["servername"] = host
      end
    end

    if server_facts["serverip"].nil? && server_facts["serverip6"].nil?
      Puppet.warning _("Could not retrieve either serverip or serverip6 fact")
    end

    server_facts
  end
end
