require 'puppet'
require 'puppet/util/autoload'

class Puppet::Interface
  require 'puppet/interface/action_manager'
  require 'puppet/interface/interface_collection'

  include Puppet::Interface::ActionManager
  extend Puppet::Interface::ActionManager

  include Puppet::Util

  # This is just so we can search for actions.  We only use its
  # list of directories to search.
  # Can't we utilize an external autoloader, or simply use the $LOAD_PATH? -pvb
  def self.autoloader
    @autoloader ||= Puppet::Util::Autoload.new(:application, "puppet/interface")
  end

  def self.interfaces
    Puppet::Interface::InterfaceCollection.interfaces
  end

  def self.interface?(name, version)
    Puppet::Interface::InterfaceCollection.interface?(name, version)
  end

  def self.register(instance)
    Puppet::Interface::InterfaceCollection.register(instance)
  end

  def self.interface(name, version, &blk)
    if interface?(name, version)
      interface = Puppet::Interface::InterfaceCollection[name, version]
      interface.instance_eval(&blk) if blk
    else
      interface = self.new(name, :version => version, &blk)
      Puppet::Interface::InterfaceCollection.register(interface)
      interface.load_actions
    end
    return interface
  end

  attr_accessor :default_format

  def set_default_format(format)
    self.default_format = format.to_sym
  end

  attr_accessor :type, :verb, :version, :arguments, :options
  attr_reader :name

  def initialize(name, options = {}, &block)
    unless options[:version]
      raise ArgumentError, "Interface #{name} declared without version!"
    end

    @name = Puppet::Interface::InterfaceCollection.underscorize(name)

    @default_format = :pson
    options.each { |opt, val| send(opt.to_s + "=", val) }

    instance_eval(&block) if block
  end

  # Try to find actions defined in other files.
  def load_actions
    path = "puppet/interface/#{name}"

    loaded = []
    Puppet::Interface.autoloader.search_directories.each do |dir|
      fdir = ::File.join(dir, path)
      next unless FileTest.directory?(fdir)

      Dir.chdir(fdir) do
        Dir.glob("*.rb").each do |file|
          aname = file.sub(/\.rb/, '')
          if loaded.include?(aname)
            Puppet.debug "Not loading duplicate action '#{aname}' for '#{name}' from '#{fdir}/#{file}'"
            next
          end
          loaded << aname
          Puppet.debug "Loading action '#{aname}' for '#{name}' from '#{fdir}/#{file}'"
          require "#{path}/#{aname}"
        end
      end
    end
  end

  def to_s
    "Puppet::Interface(#{name}, :version => #{version.inspect})"
  end
end
