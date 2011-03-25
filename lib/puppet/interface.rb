require 'puppet'
require 'puppet/util/autoload'

class Puppet::Interface
  require 'puppet/interface/action_manager'
  require 'puppet/interface/interface_collection'

  include Puppet::Interface::ActionManager
  extend Puppet::Interface::ActionManager

  include Puppet::Util

  class << self
    # This is just so we can search for actions.  We only use its
    # list of directories to search.
    # Can't we utilize an external autoloader, or simply use the $LOAD_PATH? -pvb
    def autoloader
      @autoloader ||= Puppet::Util::Autoload.new(:application, "puppet/interface")
    end

    def interfaces
      Puppet::Interface::InterfaceCollection.interfaces
    end

    def interface?(name, version)
      Puppet::Interface::InterfaceCollection.interface?(name, version)
    end

    def register(instance)
      Puppet::Interface::InterfaceCollection.register(instance)
    end

    def define(name, version, &block)
      if interface?(name, version)
        interface = Puppet::Interface::InterfaceCollection[name, version]
      else
        interface = self.new(name, version)
        Puppet::Interface::InterfaceCollection.register(interface)
        interface.load_actions
      end

      interface.instance_eval(&block) if block_given?

      return interface
    end

    alias :[] :define
  end

  attr_accessor :default_format

  def set_default_format(format)
    self.default_format = format.to_sym
  end

  attr_accessor :type, :verb, :version, :arguments, :options
  attr_reader :name

  def initialize(name, version, &block)
    unless Puppet::Interface::InterfaceCollection.validate_version(version)
      raise ArgumentError, "Cannot create interface with invalid version number '#{version}'!"
    end

    @name = Puppet::Interface::InterfaceCollection.underscorize(name)
    @version = version
    @default_format = :pson

    instance_eval(&block) if block_given?
  end

  # Try to find actions defined in other files.
  def load_actions
    path = "puppet/interface/v#{version}/#{name}"

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
    "Puppet::Interface[#{name.inspect}, #{version.inspect}]"
  end
end
