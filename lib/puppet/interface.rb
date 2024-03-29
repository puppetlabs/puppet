# frozen_string_literal: true

require_relative '../puppet'
require_relative '../puppet/util/autoload'
require 'prettyprint'

# @api public
class Puppet::Interface
  require_relative 'interface/documentation'
  require_relative 'interface/face_collection'

  require_relative 'interface/action'
  require_relative 'interface/action_builder'
  require_relative 'interface/action_manager'

  require_relative 'interface/option'
  require_relative 'interface/option_builder'
  require_relative 'interface/option_manager'

  include FullDocs

  include Puppet::Interface::ActionManager
  extend Puppet::Interface::ActionManager

  include Puppet::Interface::OptionManager
  extend Puppet::Interface::OptionManager

  include Puppet::Util

  class << self
    # This is just so we can search for actions.  We only use its
    # list of directories to search.

    # Lists all loaded faces
    # @return [Array<Symbol>] The names of the loaded faces
    def faces
      Puppet::Interface::FaceCollection.faces
    end

    # Register a face
    # @param instance [Puppet::Interface] The face
    # @return [void]
    # @api private
    def register(instance)
      Puppet::Interface::FaceCollection.register(instance)
    end

    # Defines a new Face.
    # @todo Talk about using Faces DSL inside the block
    #
    # @param name [Symbol] the name of the face
    # @param version [String] the version of the face (this should
    #   conform to {http://semver.org/ Semantic Versioning})
    # @overload define(name, version, { ... })
    # @return [Puppet::Interface] The created face
    # @api public
    # @dsl Faces
    def define(name, version, &block)
      face = Puppet::Interface::FaceCollection[name, version]
      if face.nil? then
        face = new(name, version)
        Puppet::Interface::FaceCollection.register(face)
        # REVISIT: Shouldn't this be delayed until *after* we evaluate the
        # current block, not done before? --daniel 2011-04-07
        face.load_actions
      end

      face.instance_eval(&block) if block_given?

      face
    end

    # Retrieves a face by name and version. Use `:current` for the
    # version to get the most recent available version.
    #
    # @param name [Symbol] the name of the face
    # @param version [String, :current] the version of the face
    #
    # @return [Puppet::Interface] the face
    #
    # @api public
    def face?(name, version)
      Puppet::Interface::FaceCollection[name, version]
    end

    # Retrieves a face by name and version
    #
    # @param name [Symbol] the name of the face
    # @param version [String] the version of the face
    #
    # @return [Puppet::Interface] the face
    #
    # @api public
    def [](name, version)
      face = Puppet::Interface::FaceCollection[name, version]
      unless face
        # REVISIT (#18042) no sense in rechecking if version == :current -- josh
        if Puppet::Interface::FaceCollection[name, :current]
          raise Puppet::Error, "Could not find version #{version} of #{name}"
        else
          raise Puppet::Error, "Could not find Puppet Face #{name}"
        end
      end

      face
    end

    # Retrieves an action for a face
    # @param name [Symbol] The face
    # @param action [Symbol] The action name
    # @param version [String, :current] The version of the face
    # @return [Puppet::Interface::Action] The action
    def find_action(name, action, version = :current)
      Puppet::Interface::FaceCollection.get_action_for_face(name, action, version)
    end
  end

  ########################################################################
  # Documentation.  We currently have to rewrite both getters because we share
  # the same instance between build-time and the runtime instance.  When that
  # splits out this should merge into a module that both the action and face
  # include. --daniel 2011-04-17

  # Returns the synopsis for the face. This shows basic usage and global
  # options.
  # @return [String] usage synopsis
  # @api private
  def synopsis
    build_synopsis name, '<action>'
  end

  ########################################################################

  # The name of the face
  # @return [Symbol]
  # @api private
  attr_reader :name

  # The version of the face
  # @return [SemanticPuppet::Version]
  attr_reader :version

  # The autoloader instance for the face
  # @return [Puppet::Util::Autoload]
  # @api private
  attr_reader :loader
  private :loader

  # @api private
  def initialize(name, version, &block)
    unless SemanticPuppet::Version.valid?(version)
      raise ArgumentError, _("Cannot create face %{name} with invalid version number '%{version}'!") % { name: name.inspect, version: version }
    end

    @name    = Puppet::Interface::FaceCollection.underscorize(name)
    @version = SemanticPuppet::Version.parse(version)

    # The few bits of documentation we actually demand.  The default license
    # is a favour to our end users; if you happen to get that in a core face
    # report it as a bug, please. --daniel 2011-04-26
    @authors  = []
    @license  = 'All Rights Reserved'

    @loader = Puppet::Util::Autoload.new(@name, "puppet/face/#{@name}")
    instance_eval(&block) if block_given?
  end

  # Loads all actions defined in other files.
  #
  # @return [void]
  # @api private
  def load_actions
    loader.loadall(Puppet.lookup(:current_environment))
  end

  # Returns a string representation with the face's name and version
  # @return [String]
  def to_s
    "Puppet::Face[#{name.inspect}, #{version.inspect}]"
  end
  alias_method :inspect, :to_s

  # @return [void]
  def deprecate
    @deprecated = true
  end

  # @return [Boolean]
  def deprecated?
    @deprecated
  end
  ########################################################################
  # Action decoration, whee!  You are not expected to care about this code,
  # which exists to support face building and construction.  I marked these
  # private because the implementation is crude and ugly, and I don't yet know
  # enough to work out how to make it clean.
  #
  # Once we have established that these methods will likely change radically,
  # to be unrecognizable in the final outcome.  At which point we will throw
  # all this away, replace it with something nice, and work out if we should
  # be making this visible to the outside world... --daniel 2011-04-14

  private

  # @return [void]
  # @api private
  def __invoke_decorations(type, action, passed_args = [], passed_options = {})
    [:before, :after].member?(type) or fail "unknown decoration type #{type}"

    # Collect the decoration methods matching our pass.
    methods = action.options.select do |name|
      passed_options.has_key? name
    end.map do |name|
      action.get_option(name).__decoration_name(type)
    end

    methods.reverse! if type == :after

    # Exceptions here should propagate up; this implements a hook we can use
    # reasonably for option validation.
    methods.each do |hook|
      respond_to? hook and __send__(hook, action, passed_args, passed_options)
    end
  end

  # @return [void]
  # @api private
  def __add_method(name, proc)
    meta_def(name, &proc)
    method(name).unbind
  end

  # @return [void]
  # @api private
  def self.__add_method(name, proc)
    define_method(name, proc)
    instance_method(name)
  end
  private_class_method :__add_method
end
