require 'puppet'
require 'puppet/util/autoload'

class Puppet::Interface
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
      @autoloader ||= Puppet::Util::Autoload.new(:application, "puppet/faces")
    end

    def faces
      Puppet::Interface::FaceCollection.faces
    end

    def face?(name, version)
      Puppet::Interface::FaceCollection.face?(name, version)
    end

    def register(instance)
      Puppet::Interface::FaceCollection.register(instance)
    end

    def define(name, version, &block)
      if face?(name, version)
        face = Puppet::Interface::FaceCollection[name, version]
      else
        face = self.new(name, version)
        Puppet::Interface::FaceCollection.register(face)
        # REVISIT: Shouldn't this be delayed until *after* we evaluate the
        # current block, not done before? --daniel 2011-04-07
        face.load_actions
      end

      face.instance_eval(&block) if block_given?

      return face
    end

    def [](name, version)
      unless face = Puppet::Interface::FaceCollection[name, version]
        if current = Puppet::Interface::FaceCollection[name, :current]
          raise Puppet::Error, "Could not find version #{version} of #{current}"
        else
          raise Puppet::Error, "Could not find Puppet Face #{name.inspect}"
        end
      end
      face
    end
  end

  attr_accessor :default_format

  def set_default_format(format)
    self.default_format = format.to_sym
  end

  attr_accessor :type, :verb, :version, :arguments
  attr_reader :name

  def initialize(name, version, &block)
    unless Puppet::Interface::FaceCollection.validate_version(version)
      raise ArgumentError, "Cannot create face #{name.inspect} with invalid version number '#{version}'!"
    end

    @name = Puppet::Interface::FaceCollection.underscorize(name)
    @version = version
    @default_format = :pson

    instance_eval(&block) if block_given?
  end

  # Try to find actions defined in other files.
  def load_actions
    path = "puppet/faces/#{name}"

    loaded = []
    [path, "#{name}@#{version}/#{path}"].each do |path|
      Puppet::Interface.autoloader.search_directories.each do |dir|
        fdir = ::File.join(dir, path)
        next unless FileTest.directory?(fdir)

        Dir.chdir(fdir) do
          Dir.glob("*.rb").each do |file|
            aname = file.sub(/\.rb/, '')
            if loaded.include?(aname)
              Puppet.debug "Not loading duplicate action '#{aname}' for '#{name}' from '#{fdir}/#{file}'"
              next
            end
            loaded << aname
            Puppet.debug "Loading action '#{aname}' for '#{name}' from '#{fdir}/#{file}'"
            require "#{Dir.pwd}/#{aname}"
          end
        end
      end
    end
  end

  def to_s
    "Puppet::Faces[#{name.inspect}, #{version.inspect}]"
  end
end
