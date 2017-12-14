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
# The above example does not declare an implementation which makes it exactly similar
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
# Anatomy of a data type
# ---
#
# Data types consist of an interface and an implementation. A data type can often be used
# by only declaring the interface. Unless an implementation is found it will be automatically
# generated.
#
# In some cases, the generated implementation is not enough. In other cases it might be
# necessary to declare a data type that maps to an already existing implementation.
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
# Assumes the following class is declared under 'lib/auth/utils' in the module:
#
#   class Auth::Utils::User
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
#     # This require is optional and only needed in case
#     # the implementation is not loaded by other means.
#     require 'auth/utils/user.rb'
#
#     implementation_class Auth::Utils::User
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

  class TypeBuilder
    attr_accessor :interface, :implementation, :implementation_class

    def initialize(type_name)
      @type_name = type_name
      @implementation = nil
      @implementation_class = nil
    end

    def create_type(loader)
      raise ArgumentError, _('a type must have an interface') unless @interface.is_a?(String)
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
          Puppet::Pops::Loaders.implementation_registry.register_implementation(created_type, @implementation_class, loader)
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
  # @api private
  class TypeBuilderAPI
    def initialize(type_builder)
      @type_builder = type_builder
    end

    def interface(type_string)
      raise ArgumentError, _('a type can only have one interface') unless @type_builder.interface.nil?
      @type_builder.interface = type_string
    end

    def implementation(type_base = nil, &block)
      raise ArgumentError, _('a type can only have one implementation') if @type_builder.has_implementation?
      @type_builder.implementation = block
    end

    def implementation_class(ruby_class)
      raise ArgumentError, _('a type can only have one implementation') if @type_builder.has_implementation?
      @type_builder.implementation_class = ruby_class
    end
  end
end
