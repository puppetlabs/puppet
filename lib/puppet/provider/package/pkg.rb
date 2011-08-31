require 'puppet/provider/package'

Puppet::Type.type(:package).provide :pkg, :parent => Puppet::Provider::Package do
  desc "OpenSolaris image packaging system. See pkg(5) for more information"

  commands :pkg => "/usr/bin/pkg"

  confine :operatingsystem => :solaris

  #defaultfor [:operatingsystem => :solaris, :kernelrelease => "5.11"]

  def self.instances
    packages = []

    cmd = "#{command(:pkg)} list -H"
    execpipe(cmd) do |process|
      hash = {}

      # now turn each returned line into a package object
      process.each { |line|
        if hash = parse_line(line)
          packages << new(hash)
        end
      }
    end

    packages
  end

  self::REGEX = %r{^(\S+)\s+(\S+)\s+(\S+)\s+}
  self::FIELDS = [:name, :version, :status]

  def self.parse_line(line)
    hash = {}
    if match = self::REGEX.match(line)

      self::FIELDS.zip(match.captures) { |field,value|
        hash[field] = value
      }

      hash[:provider] = self.name
      hash[:error] = "ok"

      if hash[:status] == "installed"
        hash[:ensure] = :present
      else
        hash[:ensure] = :absent
      end
    else
      Puppet.warning "Failed to match 'pkg list' line #{line.inspect}"
      return nil
    end

    hash
  end

  # return the version of the package
  # TODO deal with multiple publishers
  def latest
    version = nil
    pkg(:list, "-Ha", @resource[:name]).split("\n").each do |line|
      v = line.split[2]
      case v
      when "known"
        return v
      when "installed"
        version = v
      else
        Puppet.warn "unknown package state for #{@resource[:name]}: #{v}"
      end
    end
    version
  end

  # install the package
  def install
    pkg :install, @resource[:name]
  end

  # uninstall the package
  def uninstall
    pkg :uninstall, '-r', @resource[:name]
  end

  # update the package to the latest version available
  def update
    self.install
  end

  # list a specific package
  def query
    begin
      output = pkg(:list, "-H", @resource[:name])
    rescue Puppet::ExecutionFailure
      # pkg returns 1 if the package is not found.
      return {:ensure => :absent, :status => 'missing',
        :name => @resource[:name], :error => 'ok'}
    end

    hash = self.class.parse_line(output) ||
      {:ensure => :absent, :status => 'missing', :name => @resource[:name], :error => 'ok'}

    raise Puppet::Error.new( "Package #{hash[:name]}, version #{hash[:version]} is in error state: #{hash[:error]}") if hash[:error] != "ok"

    hash
  end
end
