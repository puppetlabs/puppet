#
# This system manages an extensible set of metadata about plugins which it
#   collects by searching for files named "plugin_init.rb" in a series of
#   directories.  Initially, these are simply the $LOAD_PATH.
#
# The contents of each file found is executed in the context of a Puppet::Plugins
#    object (and thus scoped).  An example file might contain:
#
# -------------------------------------------------------
#      @name = "Greet the CA"
#
#      @description = %q{
#        This plugin causes a friendly greeting to print out on a master
#        that is operating as the CA, after it has been set up but before
#        it does anything.
#      }
#
#      def after_application_setup(options)
#        if options[:application_object].is_a?(Puppet::Application::Master) && Puppet::SSL::CertificateAuthority.ca?
#          puts "Hey, this is the CA!"
#        end
#      end
# -------------------------------------------------------
#
# Note that the instance variables are local to this Puppet::Plugin (and so may be used
#   for maintaining state, etc.) but the plugin system does not provide any thread safety
#   assurances, so they may not be adequate for some complex use cases.


module Puppet
  class Plugins
    Paths  = [] # Where we might find plugin initialization code
    Loaded = [] # Code we have found (one-to-one with paths once searched)
    #
    # Return all the Puppet::Plugins we know about, searching any new paths
    #
    def self.known
      Paths[Loaded.length...Paths.length].each { |path|
        file = File.join(path,'plugin_init.rb')
        Loaded << (Puppet::FileSystem.exist?(file) && new(file))
      }
      Loaded.compact
    end
    #
    # Add more places to look for plugins without adding duplicates or changing the
    #   order of ones we've already found.
    #
    def self.look_in(*paths)
      Paths.replace Paths | paths.flatten.collect { |path| File.expand_path(path) }
    end
    #
    # Initially just look in $LOAD_PATH
    #
    look_in $LOAD_PATH
    #
    # Calling methods (hooks) on the class calls the method of the same name on
    #   all plugins that use that hook, passing in the same arguments to each
    #   and returning an array containing the results returned by each plugin as
    #   an array of [plugin_name,result] pairs.
    #
    def self.method_missing(hook,*args,&block)
      known.
        select  { |p| p.respond_to? hook }.
        collect { |p| [p.name,p.send(hook,*args,&block)] }
    end
    #
    #
    #
    attr_reader :path,:name
    def initialize(path)
      @name = @path = path
      class << self
        private
        def define_hooks
          eval File.read(path),nil,path,1
        end
      end
      define_hooks
    end
  end
end

