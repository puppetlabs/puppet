require 'puppet/confiner'

# A simple class for modeling encoding formats for moving
# instances around the network.
class Puppet::Network::Format
  include Puppet::Confiner

  attr_reader :name, :mime
  attr_accessor :intern_method, :render_method, :intern_multiple_method, :render_multiple_method, :weight, :required_methods, :extension, :charset

  def init_attribute(name, default)
    value = @options.delete(name)
    value = default if value.nil?

    self.send(name.to_s + "=", value)
  end

  def initialize(name, options = {}, &block)
    @name = name.to_s.downcase.intern

    @options = options

    # This must be done early the values can be used to set required_methods
    define_method_names

    method_list = {
      :intern_method => "from_#{name}",
      :intern_multiple_method => "from_multiple_#{name}",
      :render_multiple_method => "to_multiple_#{name}",
      :render_method => "to_#{name}"
    }

    init_attribute(:mime, "text/#{name}")
    init_attribute(:weight, 5)
    init_attribute(:required_methods, method_list.keys)
    init_attribute(:extension, name.to_s)
    init_attribute(:charset, nil)

    method_list.each do |method, value|
      init_attribute(method, value)
    end

    raise ArgumentError, _("Unsupported option(s) %{options_list}") % { options_list: @options.keys } unless @options.empty?

    @options = nil

    instance_eval(&block) if block_given?
  end

  def intern(klass, text)
    return klass.send(intern_method, text) if klass.respond_to?(intern_method)
    raise NotImplementedError, "#{klass} does not respond to #{intern_method}; can not intern instances from #{mime}"
  end

  def intern_multiple(klass, text)
    return klass.send(intern_multiple_method, text) if klass.respond_to?(intern_multiple_method)
    raise NotImplementedError, "#{klass} does not respond to #{intern_multiple_method}; can not intern multiple instances from #{mime}"
  end

  def mime=(mime)
    @mime = mime.to_s.downcase
  end

  def render(instance)
    return instance.send(render_method) if instance.respond_to?(render_method)
    raise NotImplementedError, "#{instance.class} does not respond to #{render_method}; can not render instances to #{mime}"
  end

  def render_multiple(instances)
    # This method implicitly assumes that all instances are of the same type.
    return instances[0].class.send(render_multiple_method, instances) if instances[0].class.respond_to?(render_multiple_method)
    raise NotImplementedError, _("%{klass} does not respond to %{method}; can not render multiple instances to %{mime}") %
        { klass: instances[0].class, method: render_multiple_method, mime: mime }
  end

  def required_methods_present?(klass)
    [:intern_method, :intern_multiple_method, :render_multiple_method].each do |name|
      return false unless required_method_present?(name, klass, :class)
    end

    return false unless required_method_present?(:render_method, klass, :instance)

    true
  end

  def supported?(klass)
    suitable? and required_methods_present?(klass)
  end

  def to_s
    "Puppet::Network::Format[#{name}]"
  end

  private

  def define_method_names
    @intern_method = "from_#{name}"
    @render_method = "to_#{name}"
    @intern_multiple_method = "from_multiple_#{name}"
    @render_multiple_method = "to_multiple_#{name}"
  end

  def required_method_present?(name, klass, type)
    return true unless required_methods.include?(name)

    method = send(name)

    return(type == :class ? klass.respond_to?(method) : klass.method_defined?(method))
  end
end
