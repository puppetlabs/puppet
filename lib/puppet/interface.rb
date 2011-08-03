require 'puppet'
require 'puppet/util/autoload'
require 'puppet/interface/documentation'
require 'prettyprint'
require 'semver'

class Puppet::Interface
  include FullDocs

  require 'puppet/interface/face_collection'

  require 'puppet/interface/action_manager'
  include Puppet::Interface::ActionManager
  extend Puppet::Interface::ActionManager

  require 'puppet/interface/option_manager'
  include Puppet::Interface::OptionManager
  extend Puppet::Interface::OptionManager

  include Puppet::Util

  class << self
    # This is just so we can search for actions.  We only use its
    # list of directories to search.
    # Can't we utilize an external autoloader, or simply use the $LOAD_PATH? -pvb
    def autoloader
      @autoloader ||= Puppet::Util::Autoload.new(:application, "puppet/face")
    end

    def faces
      Puppet::Interface::FaceCollection.faces
    end

    def register(instance)
      Puppet::Interface::FaceCollection.register(instance)
    end

    def define(name, version, &block)
      face = Puppet::Interface::FaceCollection[name, version]
      if face.nil? then
        face = self.new(name, version)
        Puppet::Interface::FaceCollection.register(face)
        # REVISIT: Shouldn't this be delayed until *after* we evaluate the
        # current block, not done before? --daniel 2011-04-07
        face.load_actions
      end

      face.instance_eval(&block) if block_given?

      return face
    end

    def face?(name, version)
      Puppet::Interface::FaceCollection[name, version]
    end

    def [](name, version)
      unless face = Puppet::Interface::FaceCollection[name, version]
        if current = Puppet::Interface::FaceCollection[name, :current]
          raise Puppet::Error, "Could not find version #{version} of #{name}"
        else
          raise Puppet::Error, "Could not find Puppet Face #{name.inspect}"
        end
      end
      face
    end

    def find_action(name, action, version = :current)
      Puppet::Interface::FaceCollection.get_action_for_face(name, action, version)
    end
  end

  def set_default_format(format)
    Puppet.warning("set_default_format is deprecated (and ineffective); use render_as on your actions instead.")
  end


  ########################################################################
  # Documentation.  We currently have to rewrite both getters because we share
  # the same instance between build-time and the runtime instance.  When that
  # splits out this should merge into a module that both the action and face
  # include. --daniel 2011-04-17
  def synopsis
    build_synopsis self.name, '<action>'
  end


  ########################################################################
  attr_reader :name, :version

  def initialize(name, version, &block)
    unless SemVer.valid?(version)
      raise ArgumentError, "Cannot create face #{name.inspect} with invalid version number '#{version}'!"
    end

    @name    = Puppet::Interface::FaceCollection.underscorize(name)
    @version = SemVer.new(version)

    # The few bits of documentation we actually demand.  The default license
    # is a favour to our end users; if you happen to get that in a core face
    # report it as a bug, please. --daniel 2011-04-26
    @authors  = []
    @license  = 'All Rights Reserved'

    instance_eval(&block) if block_given?
  end

  # Try to find actions defined in other files.
  def load_actions
    Puppet::Interface.autoloader.search_directories.each do |dir|
      Dir.glob(File.join(dir, "puppet/face/#{name}", "*.rb")).each do |file|
        action = file.sub(dir, '').sub(/^[\\\/]/, '').sub(/\.rb/, '')
        Puppet.debug "Loading action '#{action}' for '#{name}' from '#{dir}/#{action}.rb'"
        require(action)
      end
    end
  end

  def to_s
    "Puppet::Face[#{name.inspect}, #{version.inspect}]"
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
      respond_to? hook and self.__send__(hook, action, passed_args, passed_options)
    end
  end

  def __add_method(name, proc)
    meta_def(name, &proc)
    method(name).unbind
  end
  def self.__add_method(name, proc)
    define_method(name, proc)
    instance_method(name)
  end
end
