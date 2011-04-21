require 'puppet'
require 'puppet/face'

class Puppet::Face::Indirector < Puppet::Face
  option "--terminus TERMINUS" do
    desc "REVISIT: You can select a terminus, which has some bigger effect
that we should describe in this file somehow."

    before_action do |action, args, options|
      set_terminus(options[:terminus])
    end

    after_action do |action, args, options|
      indirection.reset_terminus_class
    end
  end

  def self.indirections
    Puppet::Indirector::Indirection.instances.collect { |t| t.to_s }.sort
  end

  def self.terminus_classes(indirection)
    Puppet::Indirector::Terminus.terminus_classes(indirection.to_sym).collect { |t| t.to_s }.sort
  end

  def call_indirection_method(method, *args)
    options = args.last

    begin
      result = indirection.__send__(method, *args)
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      raise "Could not call '#{method}' on '#{indirection_name}': #{detail}"
    end

    return result
  end

  action :destroy do
    when_invoked { |*args| call_indirection_method(:destroy, *args) }
  end

  action :find do
    when_invoked { |*args| call_indirection_method(:find, *args) }
  end

  action :save do
    when_invoked { |*args| call_indirection_method(:save, *args) }
  end

  action :search do
    when_invoked { |*args| call_indirection_method(:search, *args) }
  end

  # Print the configuration for the current terminus class
  action :info do
    when_invoked do |*args|
      if t = indirection.terminus_class
        puts "Run mode '#{Puppet.run_mode.name}': #{t}"
      else
        $stderr.puts "No default terminus class for run mode '#{Puppet.run_mode.name}'"
      end
    end
  end

  attr_accessor :from

  def indirection_name
    @indirection_name || name.to_sym
  end

  # Here's your opportunity to override the indirection name.  By default it
  # will be the same name as the face.
  def set_indirection_name(name)
    @indirection_name = name
  end

  # Return an indirection associated with a face, if one exists;
  # One usually does.
  def indirection
    unless @indirection
      @indirection = Puppet::Indirector::Indirection.instance(indirection_name)
      @indirection or raise "Could not find terminus for #{indirection_name}"
    end
    @indirection
  end

  def set_terminus(from)
    begin
      indirection.terminus_class = from
    rescue => detail
      raise "Could not set '#{indirection.name}' terminus to '#{from}' (#{detail}); valid terminus types are #{self.class.terminus_classes(indirection.name).join(", ") }"
    end
  end
end
