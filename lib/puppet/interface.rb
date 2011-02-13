require 'puppet'

class Puppet::Interface

  class << self
    attr_accessor :default_format

    def set_default_format(format)
      self.default_format = format.to_sym
    end
  end

  # This is just so we can search for actions.  We only use its
  # list of directories to search.
  def self.autoloader
    require 'puppet/util/autoload'
    @autoloader ||= Puppet::Util::Autoload.new(:application, "puppet/interface")
  end

  # Declare that this app can take a specific action, and provide
  # the code to do so.
  def self.action(name, &block)
    @actions ||= []
    name = name.to_s.downcase.to_sym
    raise "Action #{name} already defined for #{self}" if actions.include?(name)

    @actions << name

    define_method(name, &block)
  end

  def self.actions
    @actions ||= []
    (if superclass.respond_to?(:actions)
      @actions + superclass.actions
    else
      @actions
    end).sort { |a,b| a.to_s <=> b.to_s }
  end

  # Return an interface by name, loading from disk if necessary.
  def self.interface(name)
    require "puppet/interface/#{name.to_s.downcase}"
    self.const_get(name.to_s.capitalize)
  rescue Exception => detail
    puts detail.backtrace if Puppet[:trace]
    $stderr.puts "Unable to find interface '#{name.to_s}': #{detail}."
    Kernel::exit(1)
  end

  # Try to find actions defined in other files.
  def self.load_actions
    path = "puppet/interface/#{name}"

    autoloader.search_directories.each do |dir|
      fdir = ::File.join(dir, path)
      next unless FileTest.directory?(fdir)

      Dir.glob("#{fdir}/*.rb").each do |file|
        Puppet.info "Loading actions for '#{name}' from '#{file}'"
        require file
      end
    end
  end

  # Return the interface name.
  def self.name
    @name || self.to_s.sub(/.+::/, '').downcase
  end

  attr_accessor :type, :verb, :name, :arguments

  def action?(name)
    self.class.actions.include?(name.to_sym)
  end

  # Print the configuration for the current terminus class
  action :showconfig do |*args|
    if t = indirection.terminus_class
      puts "Run mode #{Puppet.run_mode}: #{t}"
    else
      $stderr.puts "No default terminus class for run mode #{Puppet.run_mode}"
    end
  end

  def initialize(options = {})
    options.each { |opt, val| send(opt.to_s + "=", val) }

    Puppet::Util::Log.newdestination :console

    self.class.load_actions
  end

end
