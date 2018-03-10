# Data types in the Puppet Language can have implementations written in Ruby
# and distributed in puppet modules. A data type can be declared together with
# its implementation by creating a file in 'lib/puppet/functions/<modulename>'.
# The name of the file must be the downcased name of the data type followed by
# the extension '.rb'.
#
# A data type is created by calling {Puppet::DataTypes.create_type(<type name>)}
# and passing it a block that defines the data type interface and implementation.
#
# Data types are namespaced inside the modules that contains them. The name of the
# data type is prefixed with the name of the module. As with all type names, each
# segment of the name must start with an uppercase letter.
#
# @example A simple data type
#   Puppet::DataTypes.create_type('Auth::User') do
#     interface <<-PUPPET
#       attributes => {
#         name => String,
#         email => String
#       }
#     PUPPET
#   end
#
# The above example does not declare an implementation which makes it equivalent
# to adding the following contents in a file named 'user.pp' under the 'types' directory
# of the module root.
#
#   type Auth::User = Object[
#     attributes => {
#       name => String,
#       email => String
#     }]
#
# Both declarations are valid and will be found by the module loader.
#
# Structure of a data type
# ---
#
# A Data Type consists of an interface and an implementation. Unless a registered implementation
# is found, the type system will automatically generate one. An  automatically generated
# implementation is all that is needed when the interface fully  defines the behaviour (for
# example in the common case when the data type has no other behaviour than having attributes).
#
# When the automatically generated implementation is not sufficient, one must be implemented and
# registered. The implementation can either be done next to the interface definition by passing
# a block to `implementation`, or map to an existing implementation class by passing the class
# as an argument to `implementation_class`. An implementation class does not have to be special
# in other respects than that it must implemented the type's interface. This makes it possible
# to use existing Ruby data types as data types in the puppet language.
#
# Note that when using `implementation_class` there can only be one such implementation across
# all environments managed by one puppet server and you must handle and install these
# implementations as if they are part of the puppet platform. In contrast; the type
# implementations that are done inside of the type's definition are safe to use in different
# versions in different environments (given that they do not need additional external logic to
# be loaded).
#
# When using an `implementation_class` it is sometimes desirable to load this class from the
# 'lib' directory of the module. The method `load_file` is provided to facilitate such a load.
# The `load_file` will use the `Puppet::Util::Autoload` to search for the given file in the 'lib'
# directory of the current environment and the 'lib' directory in each included module.
#
# @example Adding implementation on top of the generated type using `implementation`
#   Puppet::DataTypes.create_type('Auth::User') do
#     interface <<-PUPPET
#       attributes => {
#         name => String,
#         email => String,
#         year_of_birth => Integer,
#         age => { type => Integer, kind => derived }
#       }
#       PUPPET
#
#     implementation do
#       def age
#         DateTime.now.year - @year_of_birth
#       end
#     end
#   end
#
# @example Appointing an already existing implementation class
#
# Assumes the following class is declared under 'lib/puppetx/auth' in the module:
#
#   class PuppetX::Auth::User
#     attr_reader :name, :year_of_birth
#     def initialize(name, year_of_birth)
#       @name = name
#       @year_of_birth = year_of_birth
#     end
#
#     def age
#       DateTime.now.year - @year_of_birth
#     end
#
#     def send_text(sender, text)
#       sender.send_text_from(@name, text)
#     end
#   end
#
# Then the type declaration can look like this:
#
#   Puppet::DataTypes.create_type('Auth::User') do
#     interface <<-PUPPET
#       attributes => {
#         name => String,
#         email => String,
#         year_of_birth => Integer,
#         age => { type => Integer, kind => derived }
#       },
#       functions => {
#         send_text => Callable[Sender, String[1]]
#       }
#       PUPPET
#
#     # This load_file is optional and only needed in case
#     # the implementation is not loaded by other means.
#     load_file 'puppetx/auth/user'
#
#     implementation_class PuppetX::Auth::User
#   end
#
module Puppet::DataTypes
  def self.create_type(type_name, &block)
    # Ruby < 2.1.0 does not have method on Binding, can only do eval
    # and it will fail unless protected with an if defined? if the local
    # variable does not exist in the block's binder.
    #
    begin
      loader = block.binding.eval('loader_injected_arg if defined?(loader_injected_arg)')
      create_loaded_type(type_name, loader, &block)
    rescue StandardError => e
      raise ArgumentError, _("Data Type Load Error for type '%{type_name}': %{message}") % {type_name: type_name, message: e.message}
    end

  end

  def self.create_loaded_type(type_name, loader, &block)
    builder = TypeBuilder.new(type_name.to_s)
    api = TypeBuilderAPI.new(builder).freeze
    api.instance_eval(&block)
    builder.create_type(loader)
  end

  # @api private
  class TypeBuilder
    attr_accessor :interface, :implementation, :implementation_class

    def initialize(type_name)
      @type_name = type_name
      @implementation = nil
      @implementation_class = nil
    end

    def create_type(loader)
      raise ArgumentError, _('a data type must have an interface') unless @interface.is_a?(String)
      created_type = Puppet::Pops::Types::PObjectType.new(
        @type_name,
        Puppet::Pops::Parser::EvaluatingParser.new.parse_string("{ #{@interface} }").body)

      if !@implementation_class.nil?
        if @implementation_class < Puppet::Pops::Types::PuppetObject
          @implementation_class.instance_eval do
            include Puppet::Pops::Types::PuppetObject
            @_pcore_type = created_type

            def self._pcore_type
              @_pcore_type
            end
          end
        else
          Puppet::Pops::Loaders.implementation_registry.register_implementation(created_type, @implementation_class)
        end
        created_type.implementation_class = @implementation_class
      elsif !@implementation.nil?
        created_type.implementation_override = @implementation
      end
      created_type
    end

    def has_implementation?
      !(@implementation_class.nil? && @implementation.nil?)
    end
  end

  # The TypeBuilderAPI class exposes only those methods that the builder API provides
  # @api public
  class TypeBuilderAPI
    # @api private
    def initialize(type_builder)
      @type_builder = type_builder
    end

    def interface(type_string)
      raise ArgumentError, _('a data type can only have one interface') unless @type_builder.interface.nil?
      @type_builder.interface = type_string
    end

    def implementation(&block)
      raise ArgumentError, _('a data type can only have one implementation') if @type_builder.has_implementation?
      @type_builder.implementation = block
    end

    def implementation_class(ruby_class)
      raise ArgumentError, _('a data type can only have one implementation') if @type_builder.has_implementation?
      @type_builder.implementation_class = ruby_class
    end

    def load_file(file_name)
      Puppet::Util::Autoload.load_file(file_name, nil)
    end
  end
end
