#
# Group Puppet provider for AIX. It uses standard commands to manage groups:
#  mkgroup, rmgroup, lsgroup, chgroup
#
# Author::    Hector Rivas Gandara <keymon@gmail.com>
#
require 'puppet/provider/aixobject'

Puppet::Type.type(:group).provide :aix, :parent => Puppet::Provider::AixObject do
  desc "Group management for AIX."

  # This will the default provider for this platform
  defaultfor :operatingsystem => :aix
  confine :operatingsystem => :aix

  # Provider features
  has_features :manages_aix_lam
  has_features :manages_members

  # Commands that manage the element
  commands :list      => "/usr/sbin/lsgroup"
  commands :add       => "/usr/bin/mkgroup"
  commands :delete    => "/usr/sbin/rmgroup"
  commands :modify    => "/usr/bin/chgroup"

  # Group attributes to ignore
  def self.attribute_ignore
    []
  end

  # AIX attributes to properties mapping.
  #
  # Valid attributes to be managed by this provider.
  # It is a list with of hash
  #  :aix_attr      AIX command attribute name
  #  :puppet_prop   Puppet property name
  #  :to            Method to adapt puppet property to aix command value. Optional.
  #  :from          Method to adapt aix command value to puppet property. Optional
  self.attribute_mapping = [
    #:name => :name,
    {:aix_attr => :id,       :puppet_prop => :gid },
    {:aix_attr => :users,    :puppet_prop => :members,
      :from => :users_from_attr},
    {:aix_attr => :attributes, :puppet_prop => :attributes},
  ]

  #--------------
  # Command definition

  # Return the IA module arguments based on the resource param ia_load_module
  def get_ia_module_args
    if @resource[:ia_load_module]
      ["-R", @resource[:ia_load_module].to_s]
    else
      []
    end
  end

  def lscmd(value=@resource[:name])
    [self.class.command(:list)] +
      self.get_ia_module_args +
      [ value]
  end

  def lsallcmd()
    lscmd("ALL")
  end

  def addcmd(extra_attrs = [])
    # Here we use the @resource.to_hash to get the list of provided parameters
    # Puppet does not call to self.<parameter>= method if it does not exists.
    #
    # It gets an extra list of arguments to add to the user.
    [self.class.command(:add) ] +
      self.get_ia_module_args +
      self.hash2args(@resource.to_hash) +
      extra_attrs + [@resource[:name]]
  end

  def modifycmd(hash = property_hash)
    args = self.hash2args(hash)
    return nil if args.empty?

    [self.class.command(:modify)] +
      self.get_ia_module_args +
      args + [@resource[:name]]
  end

  def deletecmd
    [self.class.command(:delete)] +
      self.get_ia_module_args +
      [@resource[:name]]
  end


  #--------------
  # Overwrite get_arguments to add the attributes' arguments
  def get_arguments(key, value, mapping, objectinfo)
    # In the case of attributes, return a list of key=value
    if key == :attributes
      unless value and value.is_a? Hash
        raise Puppet::Error, _("Attributes must be a list of pairs key=value on %{resource}[%{name}]") %
            { resource: @resource.class.name, name: @resource.name }
      end
      return value.select { |k,v| true }.map { |pair| pair.join("=") }
    end
    super(key, value, mapping, objectinfo)
  end

  def filter_attributes(hash)
    # Return only not managed attributes.
    hash.select {
        |k,v| !self.class.attribute_mapping_from.include?(k) and
                !self.class.attribute_ignore.include?(k)
      }.inject({}) {
        |h, array| h[array[0]] = array[1]; h
      }
  end

  def attributes
    filter_attributes(getosinfo(false))
  end

  def attributes=(attr_hash)
    #self.class.validate(param, value)
    param = :attributes
    cmd = modifycmd({param => filter_attributes(attr_hash)})
    if cmd
      begin
        execute(cmd)
      rescue Puppet::ExecutionFailure  => detail
        raise Puppet::Error, _("Could not set %{param} on %{resource}[%{name}]: %{detail}") % { param: param, resource: @resource.class.name, name: @resource.name, detail: detail }, detail.backtrace
      end
    end
  end

  # Force convert users it a list.
  def users_from_attr(value)
    (value.is_a? String) ? value.split(',') : value
  end


end
