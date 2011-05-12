require 'puppet/face'

class Puppet::Indirector::Face < Puppet::Face
  option "--terminus TERMINUS" do
    summary "The indirector terminus to use for this action"
    description <<-EOT
Indirector faces expose indirected subsystems of Puppet. These
subsystems are each able to retrieve and alter a specific type of data
(with the familiar actions of `find`, `search`, `save`, and `destroy`)
from an arbitrary number of pluggable backends. In Puppet parlance,
these backends are called terminuses.

Almost all indirected subsystems have a `rest` terminus that interacts
with the puppet master's data. Most of them have additional terminuses
for various local data models, which are in turn used by the indirected
subsystem on the puppet master whenever it receives a remote request.

The terminus for an action is often determined by context, but
occasionally needs to be set explicitly. See the "Notes" section of this
face's manpage for more details.
    EOT

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

  def call_indirection_method(method, key, options)
    begin
      result = indirection.__send__(method, key, options)
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      raise "Could not call '#{method}' on '#{indirection_name}': #{detail}"
    end

    return result
  end

  action :destroy do
    summary "Delete an object"
    when_invoked { |key, options| call_indirection_method(:destroy, key, options) }
  end

  action :find do
    summary "Retrieve an object by name"
    when_invoked { |key, options| call_indirection_method(:find, key, options) }
  end

  action :save do
    summary "Create or modify an object"
    notes <<-EOT
      Save actions cannot currently be invoked from the command line, and are
      for API use only.
    EOT
    when_invoked { |key, options| call_indirection_method(:save, key, options) }
  end

  action :search do
    summary "Search for an object"
    when_invoked { |key, options| call_indirection_method(:search, key, options) }
  end

  # Print the configuration for the current terminus class
  action :info do
    summary "Print the default terminus class for this face"
    description <<-EOT
      TK So this is per-face, right? No way to tell what the default terminus
      is per-action, for subsystems that switch to REST for save but query
      locally for find?
    EOT

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
