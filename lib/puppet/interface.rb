require 'puppet'

class Puppet::Interface
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
    raise "Action #{name} already defined for #{name}" if actions.include?(name)

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

  # Return an indirection associated with an interface, if one exists
  # One usually does.
  def self.indirection
    unless @indirection
      raise "Could not find data type '#{name}' for interface '#{name}'" unless @indirection = Puppet::Indirector::Indirection.instance(name.to_sym)
    end
    @indirection
  end

  # Return an interface by name, loading from disk if necessary.
  def self.interface(name)
    require "puppet/interface/#{name.to_s.downcase}"
    self.const_get(name.to_s.capitalize)
  rescue Exception => detail
    $stderr.puts "Unable to find interface '#{name.to_s}': #{detail}."
    Kernel::exit(1)
  end

  # Return the interface name.
  def self.name
    @name || self.to_s.sub(/.+::/, '').downcase
  end

  attr_accessor :from, :type, :verb, :name, :arguments, :indirection, :format

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

  action :destroy do |name, *args|
    call_indirection_method(:destroy, name, *args)
  end

  action :find do |name, *args|
    call_indirection_method(:find, name, *args)
  end

  action :save do |name, *args|
    call_indirection_method(:save, name, *args)
  end

  action :search do |name, *args|
    call_indirection_method(:search, name, *args)
  end

  def indirection
    self.class.indirection
  end

  def initialize(options = {})
    options.each { |opt, val| send(opt.to_s + "=", val) }

    @format ||= :yaml

    Puppet::Util::Log.newdestination :console

    load_actions
  end

  def set_terminus(from)
    begin
      indirection.terminus_class = from
    rescue => detail
      raise "Could not set '#{indirection.name}' terminus to '#{from}' (#{detail}); valid terminus types are #{terminus_classes(indirection.name).join(", ") }"
    end
  end

  def call_indirection_method(method, name, *args)
    begin
      result = indirection.send(method, name, *args)
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      raise "Could not call #{method} on #{type}: #{detail}"
    end

    unless result
      raise "Could not #{verb} #{type} for #{name}"
    end

    puts result.render(format.to_sym)
  end

  # Try to find actions defined in other files.
  def load_actions
    path = "puppet/interface/#{self.class.name}"

    self.class.autoloader.search_directories.each do |dir|
      fdir = File.join(dir, path)
      next unless FileTest.directory?(fdir)

      Dir.glob("#{fdir}/*.rb").each do |file|
        Puppet.info "Loading actions for '#{self.class.name}' from '#{file}'"
        require file
      end
    end
  end

  def indirections
      Puppet::Indirector::Indirection.instances.collect { |t| t.to_s }.sort
  end

  def terminus_classes(indirection)
      Puppet::Indirector::Terminus.terminus_classes(indirection).collect { |t| t.to_s }.sort
  end
end
