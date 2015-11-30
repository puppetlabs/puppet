require 'puppet/provider/parsedfile'

Puppet::Type.type(:sshkey).provide(
  :parsed,
  :parent => Puppet::Provider::ParsedFile,
  :filetype => :flat
) do
  desc "Parse and generate host-wide known hosts files for SSH."

  text_line :comment, :match => /^#/
  text_line :blank, :match => /^\s*$/

  record_line :parsed, :fields => %w{name type key},
    :post_parse => proc { |hash|
      names = hash[:name].split(",", -1)
      hash[:name]  = names.shift
      hash[:host_aliases] = names
    },
    :pre_gen => proc { |hash|
      if hash[:host_aliases]
        hash[:name] = [hash[:name], hash[:host_aliases]].flatten.join(",")
        hash.delete(:host_aliases)
      end
    }

  # Make sure to use mode 644 if ssh_known_hosts is newly created
  def self.default_mode
    0644
  end

  def self.default_target
    case Facter.value(:operatingsystem)
    when "Darwin"
      # Versions 10.11 and up use /etc/ssh/ssh_known_hosts
      version = Facter.value(:macosx_productversion_major)
      if version
        if Puppet::Util::Package.versioncmp(version, '10.11') >= 0
          "/etc/ssh/ssh_known_hosts"
        else
          "/etc/ssh_known_hosts"
        end
      else
        "/etc/ssh_known_hosts"
      end
    else
      "/etc/ssh/ssh_known_hosts"
    end
  end
end

