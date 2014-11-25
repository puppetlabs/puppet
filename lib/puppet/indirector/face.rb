require 'puppet/face'

class Puppet::Indirector::Face < Puppet::Face
  option "--terminus TERMINUS" do
    summary "The indirector terminus to use."
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
      message = "Could not call '#{method}' on '#{indirection_name}': #{detail}"
      Puppet.log_exception(detail, message)
      raise RuntimeError, message, detail.backtrace
    end

    return result
  end

  option "--extra HASH" do
    summary "Extra arguments to pass to the indirection request"
    description <<-EOT
      A terminus can take additional arguments to refine the operation, which
      are passed as an arbitrary hash to the back-end.  Anything passed as
      the extra value is just send direct to the back-end.
    EOT
    default_to do Hash.new end
  end

  action :destroy do
    summary "Delete an object."
    arguments "<key>"
    when_invoked {|key, options| call_indirection_method :destroy, key, options[:extra] }
  end

  action :find do
    summary "Retrieve an object by name."
    arguments "[<key>]"
    when_invoked do |*args|
      # Default the key to Puppet[:certname] if none is supplied
      if args.length == 1
        key = Puppet[:certname]
        options = args.last
      else
        key, options = *args
      end
      call_indirection_method :find, key, options[:extra]
    end
  end

  action :save do
    summary "API only: create or overwrite an object."
    arguments "<key>"
    description <<-EOT
      API only: create or overwrite an object. As the Faces framework does not
      currently accept data from STDIN, save actions cannot currently be invoked
      from the command line.
    EOT
    when_invoked {|key, options| call_indirection_method :save, key, options[:extra] }
  end

  action :search do
    summary "Search for an object or retrieve multiple objects."
    arguments "<query>"
    when_invoked {|key, options| call_indirection_method :search, key, options[:extra] }
  end

  # Print the configuration for the current terminus class
  action :info do
    summary "Print the default terminus class for this face."
    description <<-EOT
      Prints the default terminus class for this subcommand. Note that different
      run modes may have different default termini; when in doubt, specify the
      run mode with the '--run_mode' option.
    EOT

    when_invoked do |options|
      if t = indirection.terminus_class
        "Run mode '#{Puppet.run_mode.name}': #{t}"
      else
        "No default terminus class for run mode '#{Puppet.run_mode.name}'"
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
      msg = "Could not set '#{indirection.name}' terminus to '#{from}' (#{detail}); valid terminus types are #{self.class.terminus_classes(indirection.name).join(", ") }"
      raise detail, msg, detail.backtrace
    end
  end
end
