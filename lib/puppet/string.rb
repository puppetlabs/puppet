require 'puppet'
require 'puppet/util/autoload'

class Puppet::String
  require 'puppet/string/string_collection'

  require 'puppet/string/action_manager'
  include Puppet::String::ActionManager
  extend Puppet::String::ActionManager

  require 'puppet/string/option_manager'
  include Puppet::String::OptionManager
  extend Puppet::String::OptionManager

  include Puppet::Util

  class << self
    # This is just so we can search for actions.  We only use its
    # list of directories to search.
    # Can't we utilize an external autoloader, or simply use the $LOAD_PATH? -pvb
    def autoloader
      @autoloader ||= Puppet::Util::Autoload.new(:application, "puppet/string")
    end

    def strings
      Puppet::String::StringCollection.strings
    end

    def string?(name, version)
      Puppet::String::StringCollection.string?(name, version)
    end

    def register(instance)
      Puppet::String::StringCollection.register(instance)
    end

    def define(name, version, &block)
      if string?(name, version)
        string = Puppet::String::StringCollection[name, version]
      else
        string = self.new(name, version)
        Puppet::String::StringCollection.register(string)
        string.load_actions
      end

      string.instance_eval(&block) if block_given?

      return string
    end

    alias :[] :define
  end

  attr_accessor :default_format

  def set_default_format(format)
    self.default_format = format.to_sym
  end

  attr_accessor :type, :verb, :version, :arguments
  attr_reader :name

  def initialize(name, version, &block)
    unless Puppet::String::StringCollection.validate_version(version)
      raise ArgumentError, "Cannot create string #{name.inspect} with invalid version number '#{version}'!"
    end

    @name = Puppet::String::StringCollection.underscorize(name)
    @version = version
    @default_format = :pson

    instance_eval(&block) if block_given?
  end

  # Try to find actions defined in other files.
  def load_actions
    path = "puppet/string/#{name}"

    loaded = []
    [path, "#{name}@#{version}/#{path}"].each do |path|
      Puppet::String.autoloader.search_directories.each do |dir|
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
    "Puppet::String[#{name.inspect}, #{version.inspect}]"
  end
end
