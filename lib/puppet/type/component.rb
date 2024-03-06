# frozen_string_literal: true

require_relative '../../puppet'
require_relative '../../puppet/type'
require_relative '../../puppet/transaction'

Puppet::Type.newtype(:component) do
  include Enumerable

  newparam(:name) do
    desc "The name of the component.  Generally optional."
    isnamevar
  end

  # Override how parameters are handled so that we support the extra
  # parameters that are used with defined resource types.
  def [](param)
    if self.class.valid_parameter?(param)
      super
    else
      @extra_parameters[param.to_sym]
    end
  end

  # Override how parameters are handled so that we support the extra
  # parameters that are used with defined resource types.
  def []=(param, value)
    if self.class.valid_parameter?(param)
      super
    else
      @extra_parameters[param.to_sym] = value
    end
  end

  # Initialize a new component
  def initialize(*args)
    @extra_parameters = {}
    super
  end

  # Component paths are special because they function as containers.
  def pathbuilder
    if reference.type == "Class"
      myname = reference.title
    else
      myname = reference.to_s
    end
    p = parent
    if p
      [p.pathbuilder, myname]
    else
      [myname]
    end
  end

  def ref
    reference.to_s
  end

  # We want our title to just be the whole reference, rather than @title.
  def title
    ref
  end

  def title=(str)
    @reference = Puppet::Resource.new(str)
  end

  def refresh
    catalog.adjacent(self).each do |child|
      if child.respond_to?(:refresh)
        child.refresh
        child.log "triggering refresh"
      end
    end
  end

  def to_s
    reference.to_s
  end

  # Overrides the default implementation to do nothing.
  # This type contains data from class/define parameters, but does
  # not have actual parameters or properties at the Type level. We can
  # simply ignore anything flagged as sensitive here, since any
  # contained resources will handle that sensitivity themselves. There
  # is no risk of this information leaking into reports, since no
  # Component instances survive the graph transmutation.
  #
  def set_sensitive_parameters(sensitive_parameters)
  end

  private

  attr_reader :reference
end
