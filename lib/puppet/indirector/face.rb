# frozen_string_literal: true

require_relative '../../puppet/face'

class Puppet::Indirector::Face < Puppet::Face
  option "--terminus _" + _("TERMINUS") do
    summary _("The indirector terminus to use.")
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

    before_action do |_action, _args, options|
      set_terminus(options[:terminus])
    end

    after_action do |_action, _args, _options|
      indirection.reset_terminus_class
    end
  end

  def self.indirections
    Puppet::Indirector::Indirection.instances.collect(&:to_s).sort
  end

  def self.terminus_classes(indirection)
    Puppet::Indirector::Terminus.terminus_classes(indirection.to_sym).collect(&:to_s).sort
  end

  def call_indirection_method(method, key, options)
    begin
      if method == :save
        # key is really the instance to save
        result = indirection.__send__(method, key, nil, options)
      else
        result = indirection.__send__(method, key, options)
      end
    rescue => detail
      message = _("Could not call '%{method}' on '%{indirection}': %{detail}") % { method: method, indirection: indirection_name, detail: detail }
      Puppet.log_exception(detail, message)
      raise RuntimeError, message, detail.backtrace
    end

    result
  end

  action :destroy do
    summary _("Delete an object.")
    arguments _("<key>")
    when_invoked { |key, _options| call_indirection_method :destroy, key, {} }
  end

  action :find do
    summary _("Retrieve an object by name.")
    arguments _("[<key>]")
    when_invoked do |*args|
      # Default the key to Puppet[:certname] if none is supplied
      if args.length == 1
        key = Puppet[:certname]
      else
        key = args.first
      end
      call_indirection_method :find, key, {}
    end
  end

  action :save do
    summary _("API only: create or overwrite an object.")
    arguments _("<key>")
    description <<-EOT
      API only: create or overwrite an object. As the Faces framework does not
      currently accept data from STDIN, save actions cannot currently be invoked
      from the command line.
    EOT
    when_invoked { |key, _options| call_indirection_method :save, key, {} }
  end

  action :search do
    summary _("Search for an object or retrieve multiple objects.")
    arguments _("<query>")
    when_invoked { |key, _options| call_indirection_method :search, key, {} }
  end

  # Print the configuration for the current terminus class
  action :info do
    summary _("Print the default terminus class for this face.")
    description <<-EOT
      Prints the default terminus class for this subcommand. Note that different
      run modes may have different default termini; when in doubt, specify the
      run mode with the '--run_mode' option.
    EOT

    when_invoked do |_options|
      if indirection.terminus_class
        _("Run mode '%{mode}': %{terminus}") % { mode: Puppet.run_mode.name, terminus: indirection.terminus_class }
      else
        _("No default terminus class for run mode '%{mode}'") % { mode: Puppet.run_mode.name }
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
      @indirection or raise _("Could not find terminus for %{indirection}") % { indirection: indirection_name }
    end
    @indirection
  end

  def set_terminus(from)
    indirection.terminus_class = from
  rescue => detail
    msg = _("Could not set '%{indirection}' terminus to '%{from}' (%{detail}); valid terminus types are %{types}") % { indirection: indirection.name, from: from, detail: detail, types: self.class.terminus_classes(indirection.name).join(", ") }
    raise detail, msg, detail.backtrace
  end
end
