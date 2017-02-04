require 'puppet/provider/parsedfile'

Puppet::Type.type(:maillist).provide(:mailman) do
  if [ "CentOS", "RedHat", "Fedora" ].any? { |os|  Facter.value(:operatingsystem) == os }
    commands :list_lists => "/usr/lib/mailman/bin/list_lists", :rmlist => "/usr/lib/mailman/bin/rmlist", :newlist => "/usr/lib/mailman/bin/newlist"
    commands :mailman => "/usr/lib/mailman/mail/mailman"
  else
    # This probably won't work for non-Debian installs, but this path is sure not to be in the PATH.
    commands :list_lists => "list_lists", :rmlist => "rmlist", :newlist => "newlist"
    commands :mailman => "/var/lib/mailman/mail/mailman"
  end

  mk_resource_methods

  # Return a list of existing mailman instances.
  def self.instances
    list_lists('--bare').
      split("\n").
      collect { |line| new(:ensure => :present, :name => line.strip) }
  end

  # Prefetch our list list, yo.
  def self.prefetch(lists)
    instances.each do |prov|
      if list = lists[prov.name] || lists[prov.name.downcase]
        list.provider = prov
      end
    end
  end

  def aliases
    mailman = self.class.command(:mailman)
    name = self.name.downcase
    aliases = {name => "| #{mailman} post #{name}"}
    %w{admin bounces confirm join leave owner request subscribe unsubscribe}.each do |address|
      aliases["#{name}-#{address}"] = "| #{mailman} #{address} #{name}"
    end
    aliases
  end

  # Create the list.
  def create
    args = []
    if val = @resource[:mailserver]
      args << "--emailhost" << val
    end
    if val = @resource[:webserver]
      args << "--urlhost" << val
    end

    args << self.name
    if val = @resource[:admin]
      args << val
    else
      raise ArgumentError, _("Mailman lists require an administrator email address")
    end
    if val = @resource[:password]
      args << val
    else
      raise ArgumentError, _("Mailman lists require an administrator password")
    end
    newlist(*args)
  end

  # Delete the list.
  def destroy(purge = false)
    args = []
    args << "--archives" if purge
    args << self.name
    rmlist(*args)
  end

  # Does our list exist already?
  def exists?
    properties[:ensure] != :absent
  end

  # Clear out the cached values.
  def flush
    @property_hash.clear
  end

  # Look up the current status.
  def properties
    if @property_hash.empty?
      @property_hash = query || {:ensure => :absent}
      @property_hash[:ensure] = :absent if @property_hash.empty?
    end
    @property_hash.dup
  end

  # Remove the list and its archives.
  def purge
    destroy(true)
  end

  # Pull the current state of the list from the full list.  We're
  # getting some double entendre here....
  def query
    self.class.instances.each do |list|
      if list.name == self.name or list.name.downcase == self.name
        return list.properties
      end
    end
    nil
  end
end

