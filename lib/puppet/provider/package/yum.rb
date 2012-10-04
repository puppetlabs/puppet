require 'puppet/util/package'

Puppet::Type.type(:package).provide :yum, :parent => :rpm, :source => :rpm do
  desc "Support via `yum`."

  has_feature :versionable

  commands :yum => "yum", :rpm => "rpm"

  attr_accessor :latest_info

  if command('rpm')
    confine :true => begin
      rpm('--version')
      rescue Puppet::ExecutionFailure
        false
      else
        true
      end
  end

  defaultfor :operatingsystem => [:fedora, :centos, :redhat]

  # Rubyized version of yumhelper.py
  def self.yumhelper
    result = []
    begin
      p = IO.popen("/usr/bin/env yum check-update --quiet 2>&1")
      output = p.readlines()
      p.close
      rc = $?.exitstatus
      
      if rc == 0
        return 0
      elsif rc != 100
        return rc
      end

      skipheaders = false
      output.each do |line|
        # Yum prints a line of hyphens (old versions) or a blank line between
        # headers and package data, so skip everything before them
        if !skipheaders
          if /^((-){80}|)$/ =~ line
            skipheaders = true
          end
          next
        end

        # Skip any blank lines
        if /^[ \t]*$/ =~ line
          next
        end

        # Skip 'Obsoleting Packages' line
        if /^Obsoleting Packages *$/ =~ line
          next
        end

        # Format is:
        # Yum 1.x: name arch (epoch:)?version
        # Yum 2.0: name arch (epoch:)?version repo
        # Yum 3.x: name.arch (epoch:)?version repo
        # epoch is optional if 0

        p = line.split
        if /^(.*)\.(.*)$/ =~ p[0]
          pname = $1
          parch = $2
          pevr = p[1]
        else
          pname = p[0]
          parch = p[1]
          pevr  = p[2]
        end

        # Separate out epoch:version-release
        evr = /^(\d:)?(\S+)-(\S+)$/ =~ pevr

        if $1.nil?
          pepoch = "0"
        else
          pepoch = $1.sub(":", "")
        end

        pversion = $2
        prelease = $3

        result.push "_pkg #{pname} #{pepoch} #{pversion} #{prelease} #{parch}\n"

      end
    rescue Exception => e
      puts e
    end

    result
  end

  def self.prefetch(packages)
    raise Puppet::Error, "The yum provider can only be used as root" if Process.euid != 0
    super
    return unless packages.detect { |name, package| package.should(:ensure) == :latest }

    # collect our 'latest' info
    updates = {}
    yumhelper.each do |l|
      l.chomp!
      next if l.empty?
      if l[0,4] == "_pkg"
        hash = nevra_to_hash(l[5..-1])
        [hash[:name], "#{hash[:name]}.#{hash[:arch]}"].each  do |n|
          updates[n] ||= []
          updates[n] << hash
        end
      end
    end

    # Add our 'latest' info to the providers.
    packages.each do |name, package|
      if info = updates[package[:name]]
        package.provider.latest_info = info[0]
      end
    end
  end

  def install
    should = @resource.should(:ensure)
    self.debug "Ensuring => #{should}"
    wanted = @resource[:name]
    operation = :install

    case should
    when true, false, Symbol
      # pass
      should = nil
    else
      # Add the package version
      wanted += "-#{should}"
      is = self.query
      if is && Puppet::Util::Package.versioncmp(should, is[:ensure]) < 0
        self.debug "Downgrading package #{@resource[:name]} from version #{is[:ensure]} to #{should}"
        operation = :downgrade
      end
    end

    output = yum "-d", "0", "-e", "0", "-y", operation, wanted

    is = self.query
    raise Puppet::Error, "Could not find package #{self.name}" unless is

    # FIXME: Should we raise an exception even if should == :latest
    # and yum updated us to a version other than @param_hash[:ensure] ?
    raise Puppet::Error, "Failed to update to version #{should}, got version #{is[:ensure]} instead" if should && should != is[:ensure]
  end

  # What's the latest package version available?
  def latest
    upd = latest_info
    unless upd.nil?
      # FIXME: there could be more than one update for a package
      # because of multiarch
      return "#{upd[:epoch]}:#{upd[:version]}-#{upd[:release]}"
    else
      # Yum didn't find updates, pretend the current
      # version is the latest
      raise Puppet::DevError, "Tried to get latest on a missing package" if properties[:ensure] == :absent
      return properties[:ensure]
    end
  end

  def update
    # Install in yum can be used for update, too
    self.install
  end

  def purge
    yum "-y", :erase, @resource[:name]
  end
end
