# Adaptable is a mix-in module that adds adaptability to a class.
# This means that an adapter can
# associate itself with an instance of the class and store additional data/have behavior.
#
# This mechanism should be used when there is a desire to keep implementation concerns separate.
# In Ruby it is always possible to open and modify a class or instance to teach it new tricks, but it
# is however not possible to do this for two different versions of some service at the same time.
# The Adaptable pattern is also good when only a few of the objects of some class needs to have extra
# information (again possible in Ruby by adding instance variables dynamically). In fact, the implementation
# of Adaptable does just that; it adds an instance variable named after the adapter class and keeps an
# instance of this class in this slot.
#
# @note the implementation details; the fact that an instance variable is used to keep the adapter
#   instance data should not
#   be exploited as the implementation of _being adaptable_ may change in the future.
# @api private
#
module Puppet::Pops
module Adaptable
  # Base class for an Adapter.
  #
  # A typical adapter just defines some accessors.
  #
  # A more advanced adapter may need to setup the adapter based on the object it is adapting.
  # @example Making Duck adaptable
  #   class Duck
  #     include Puppet::Pops::Adaptable
  #   end
  # @example Giving a Duck a nick name
  #   class NickNameAdapter < Puppet::Pops::Adaptable::Adapter
  #     attr_accessor :nick_name
  #   end
  #   d = Duck.new
  #   NickNameAdapter.adapt(d).nick_name = "Daffy"
  #   NickNameAdapter.get(d).nick_name # => "Daffy"
  #
  # @example Giving a Duck a more elaborate nick name
  #   class NickNameAdapter < Puppet::Pops::Adaptable::Adapter
  #     attr_accessor :nick_name, :object
  #     def initialize o
  #       @object = o
  #       @nick_name = "Yo"
  #     end
  #     def nick_name
  #       "#{@nick_name}, the #{o.class.name}"
  #     end
  #     def NickNameAdapter.create_adapter(o)
  #       x = new o
  #       x
  #     end
  #   end
  #   d = Duck.new
  #   n = NickNameAdapter.adapt(d)
  #   n.nick_name # => "Yo, the Duck"
  #   n.nick_name = "Daffy"
  #   n.nick_name # => "Daffy, the Duck"
  # @example Using a block to set values
  #   NickNameAdapter.adapt(o) { |a| a.nick_name = "Buddy!" }
  #   NickNameAdapter.adapt(o) { |a, o| a.nick_name = "You're the best #{o.class.name} I met."}
  #
  class Adapter
    # Returns an existing adapter for the given object, or nil, if the object is not
    # adapted.
    #
    # @param o [Adaptable] object to get adapter from
    # @return [Adapter<self>] an adapter of the same class as the receiver of #get
    # @return [nil] if the given object o has not been adapted by the receiving adapter
    # @raise [ArgumentError] if the object is not adaptable
    #
    def self.get(o)
      attr_name = self_attr_name
      if o.instance_variable_defined?(attr_name)
        o.instance_variable_get(attr_name)
      else
        nil
      end
    end

    # Returns an existing adapter for the given object, or creates a new adapter if the
    # object has not been adapted, or the adapter has been cleared.
    #
    # @example Using a block to set values
    #   NickNameAdapter.adapt(o) { |a| a.nick_name = "Buddy!" }
    #   NickNameAdapter.adapt(o) { |a, o| a.nick_name = "Your the best #{o.class.name} I met."}
    # @overload adapt(o)
    # @overload adapt(o, {|adapter| block})
    # @overload adapt(o, {|adapter, o| block})
    # @param o [Adaptable] object to add adapter to
    # @yieldparam adapter [Adapter<self>] the created adapter
    # @yieldparam o [Adaptable] optional, the given adaptable
    # @param block [Proc] optional, evaluated in the context of the adapter (existing or new)
    # @return [Adapter<self>] an adapter of the same class as the receiver of the call
    # @raise [ArgumentError] if the given object o is not adaptable
    #
    def self.adapt(o, &block)
      attr_name = self_attr_name
      adapter = if o.instance_variable_defined?(attr_name) && value = o.instance_variable_get(attr_name)
        value
      else
        associate_adapter(create_adapter(o), o)
      end
      if block_given?
        case block.arity
          when 1
            block.call(adapter)
          else
            block.call(adapter, o)
        end
      end
      adapter
    end

    # Creates a new adapter, associates it with the given object and returns the adapter.
    #
    # @example Using a block to set values
    #   NickNameAdapter.adapt_new(o) { |a| a.nick_name = "Buddy!" }
    #   NickNameAdapter.adapt_new(o) { |a, o| a.nick_name = "Your the best #{o.class.name} I met."}
    # This is used when a fresh adapter is wanted instead of possible returning an
    # existing adapter as in the case of {Adapter.adapt}.
    # @overload adapt_new(o)
    # @overload adapt_new(o, {|adapter| block})
    # @overload adapt_new(o, {|adapter, o| block})
    # @yieldparam adapter [Adapter<self>] the created adapter
    # @yieldparam o [Adaptable] optional, the given adaptable
    # @param o [Adaptable] object to add adapter to
    # @param block [Proc] optional, evaluated in the context of the new adapter
    # @return [Adapter<self>] an adapter of the same class as the receiver of the call
    # @raise [ArgumentError] if the given object o is not adaptable
    #
    def self.adapt_new(o, &block)
      adapter = associate_adapter(create_adapter(o), o)
      if block_given?
        case block.arity
        when 1
          block.call(adapter)
        else
          block.call(adapter, o)
        end
      end
      adapter
    end

    # Clears the adapter set in the given object o. Returns any set adapter or nil.
    # @param o [Adaptable] the object where the adapter should be cleared
    # @return [Adapter] if an adapter was set
    # @return [nil] if the adapter has not been set
    #
    def self.clear(o)
      attr_name = self_attr_name
      if o.instance_variable_defined?(attr_name)
        o.send(:remove_instance_variable, attr_name)
      else
        nil
      end
    end

    # This base version creates an instance of the class (i.e. an instance of the concrete subclass
    # of Adapter). A Specialization may want to create an adapter instance specialized for the given target
    # object.
    # @param o [Adaptable] The object to adapt. This implementation ignores this variable, but a
    #   specialization may want to initialize itself differently depending on the object it is adapting.
    # @return [Adapter<self>] instance of the subclass of Adapter receiving the call
    #
    def self.create_adapter(o)
      new
    end

    # Associates the given adapter with the given target object
    # @param adapter [Adapter] the adapter to associate with the given object _o_
    # @param o [Adaptable] the object to adapt
    # @return [adapter] the given adapter
    #
    def self.associate_adapter(adapter, o)
      attr_name = :"@#{instance_var_name(adapter.class.name)}"
      o.instance_variable_set(attr_name, adapter)
      adapter
    end

    DOUBLE_COLON = '::'
    USCORE = '_'

    # Returns a suitable instance variable name given a class name.
    # The returned string is the fully qualified name of a class with '::' replaced by '_' since
    # '::' is not allowed in an instance variable name.
    # @param name [String] the fully qualified name of a class
    # @return [String] the name with all '::' replaced by '_'
    # @api private
    #
    def self.instance_var_name(name)
      name.split(DOUBLE_COLON).join(USCORE)
    end

    # Returns a suitable instance variable name for the _name_ of this instance. The name is created by calling
    # Adapter#instance_var_name and then cached.
    # @return [String] the instance variable name for _name_
    # @api private
    #
    def self.self_attr_name
      @attr_name_sym ||= :"@#{instance_var_name(self.name)}"
    end
  end
end
end

