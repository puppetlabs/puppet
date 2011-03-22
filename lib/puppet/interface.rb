require 'puppet'
require 'puppet/util/autoload'

class Puppet::Interface
  require 'puppet/interface/action_manager'

  include Puppet::Interface::ActionManager
  extend Puppet::Interface::ActionManager

  include Puppet::Util

  @interfaces = {}

  # This is just so we can search for actions.  We only use its
  # list of directories to search.
  # Can't we utilize an external autoloader, or simply use the $LOAD_PATH? -pvb
  def self.autoloader
    @autoloader ||= Puppet::Util::Autoload.new(:application, "puppet/interface")
  end

  def self.interfaces
    unless @loaded
      @loaded = true
      $LOAD_PATH.each do |dir|
        next unless FileTest.directory?(dir)
        Dir.chdir(dir) do
          Dir.glob("puppet/interface/*.rb").collect { |f| f.sub(/\.rb/, '') }.each do |file|
            iname = file.sub(/\.rb/, '')
            begin
              require iname
            rescue Exception => detail
              puts detail.backtrace if Puppet[:trace]
              raise "Could not load #{iname} from #{dir}/#{file}: #{detail}"
            end
          end
        end
      end
    end
    return @interfaces.keys
  end

  def self.interface?(name)
    name = underscorize(name)
    require "puppet/interface/#{name}" unless @interfaces.has_key? name
    return @interfaces.has_key? name
  rescue LoadError
    return false
  end

  def self.interface(name, &blk)
    interface = interface?(name) ? @interfaces[underscorize(name)] : new(name)
    interface.instance_eval(&blk) if block_given?
    return interface
  end

  def self.register_interface(name, instance)
    @interfaces[underscorize(name)] = instance
  end

  def self.underscorize(name)
    unless name.to_s =~ /^[-_a-z]+$/i then
      raise ArgumentError, "#{name.inspect} (#{name.class}) is not a valid interface name"
    end

    name.to_s.downcase.split(/[-_]/).join('_').to_sym
  end

  attr_accessor :default_format

  def set_default_format(format)
    self.default_format = format.to_sym
  end

  # Return the interface name.
  def name
    @name || self.to_s.sub(/.+::/, '').downcase
  end

  attr_accessor :type, :verb, :name, :arguments, :options

  def initialize(name, options = {}, &block)
    @name = self.class.underscorize(name)

    @default_format = :pson
    options.each { |opt, val| send(opt.to_s + "=", val) }

    # We have to register before loading actions,
    # since the actions require the registration
    # Use the full class name, so this works with
    # subclasses.
    Puppet::Interface.register_interface(name, self)

    load_actions

    if block_given?
      instance_eval(&block)
    end
  end

  # Try to find actions defined in other files.
  def load_actions
    path = "puppet/interface/#{name}"

    loaded = []
    self.class.autoloader.search_directories.each do |dir|
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
    "Puppet::Interface(#{name})"
  end
end
