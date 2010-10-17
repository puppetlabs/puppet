require 'puppet/resource/type'

class Puppet::DSL::ResourceTypeAPI
  def define(name, *args, &block)
    result = __mk_resource_type__(:definition, name, Hash.new, block)
    result.set_arguments(__munge_type_arguments__(args))
    nil
  end

  def hostclass(name, options = {}, &block)
    __mk_resource_type__(:hostclass, name, options, block)
    nil
  end

  def node(name, options = {}, &block)
    __mk_resource_type__(:node, name, options, block)
    nil
  end

  # Note: we don't want the user to call the following methods
  # directly.  However, we can't stop them by making the methods
  # private because the user's .rb code gets instance_eval'ed on an
  # instance of this class.  So instead we name the methods using
  # double underscores to discourage customers from calling them.

  def __mk_resource_type__(type, name, options, code)
    klass = Puppet::Resource::Type.new(type, name, options)

    klass.ruby_code = code if code

    Thread.current[:known_resource_types].add klass

    klass
  end

  def __munge_type_arguments__(args)
    args.inject([]) do |result, item|
      if item.is_a?(Hash)
        item.each { |p, v| result << [p, v] }
      else
        result << item
      end
      result
    end
  end
end
