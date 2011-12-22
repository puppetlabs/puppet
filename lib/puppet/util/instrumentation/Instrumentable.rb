require 'monitor'
require 'puppet/util/instrumentation'

# This is the central point of all declared probes.
# Every class needed to declare probes should include this module
# and declare the methods that are subject to instrumentation:
#
#   class MyClass
#     extend Puppet::Util::Instrumentation::Instrumentable
#
#     probe :mymethod
#
#     def mymethod
#       ... this is code to be instrumented ...
#     end
#   end
module Puppet::Util::Instrumentation::Instrumentable
  INSTRUMENTED_CLASSES = {}.extend(MonitorMixin)

  attr_reader :probes

  class Probe
    attr_reader :klass, :method, :label, :data

    def initialize(method, klass, options = {})
      @method = method
      @klass = klass

      @label = options[:label] || method
      @data = options[:data] || {}
    end

    def enable
      raise "Probe already enabled" if enabled?

      # We're forced to perform this copy because in the class_eval'uated
      # block below @method would be evaluated in the class context. It's better
      # to close on locally-scoped variables than to resort to complex namespacing
      # to get access to the probe instance variables.
      method = @method; label = @label; data = @data
      klass.class_eval {
        alias_method("instrumented_#{method}", method)
        define_method(method) do |*args|
          id = nil
          instrumentation_data = nil
          begin
            instrumentation_label = label.respond_to?(:call) ? label.call(self, args) : label
            instrumentation_data = data.respond_to?(:call) ? data.call(self, args) : data
            id = Puppet::Util::Instrumentation.start(instrumentation_label, instrumentation_data)
            send("instrumented_#{method}".to_sym, *args)
          ensure
            Puppet::Util::Instrumentation.stop(instrumentation_label, id, instrumentation_data || {})
          end
        end
      }
      @enabled = true
    end

    def disable
      raise "Probe is not enabled" unless enabled?

      # For the same reason as in #enable, we're forced to do a local
      # copy
      method = @method
      klass.class_eval do
        alias_method(method, "instrumented_#{method}")
        remove_method("instrumented_#{method}".to_sym)
      end
      @enabled = false
    end

    def enabled?
      !!@enabled
    end
  end

  # Declares a new probe
  #
  # It is possible to pass several options that will be later on evaluated
  # and sent to the instrumentation layer.
  #
  # label::
  #   this can either be a static symbol/string or a block. If it's a block
  #   this one will be evaluated on every call of the instrumented method and
  #   should return a string or a symbol
  #   
  # data::
  #   this can be a hash or a block. If it's a block this one will be evaluated
  #   on every call of the instrumented method and should return a hash.
  # 
  #Example:
  #
  #   class MyClass
  #     extend Instrumentable
  #
  #     probe :mymethod, :data => Proc.new { |args|  { :data => args[1] } }, :label => Proc.new { |args| args[0] }
  #
  #     def mymethod(name, options)
  #     end
  #
  #   end
  #
  def probe(method, options = {})
    INSTRUMENTED_CLASSES.synchronize {
      (@probes ||= []) << Probe.new(method, self, options)
      INSTRUMENTED_CLASSES[self] = @probes
    }
  end

  def self.probes
    @probes
  end

  def self.probe_names
    probe_names = []
    each_probe { |probe| probe_names << "#{probe.klass}.#{probe.method}" }
    probe_names
  end

  def self.enable_probes
    each_probe { |probe| probe.enable }
  end

  def self.disable_probes
    each_probe { |probe| probe.disable }
  end

  def self.clear_probes
    INSTRUMENTED_CLASSES.synchronize {
      INSTRUMENTED_CLASSES.clear
    }
    nil # do not leak our probes to the exterior world
  end

  def self.each_probe
    INSTRUMENTED_CLASSES.synchronize {
      INSTRUMENTED_CLASSES.each_key do |klass|
        klass.probes.each { |probe| yield probe }
      end
    }
    nil # do not leak our probes to the exterior world
  end
end