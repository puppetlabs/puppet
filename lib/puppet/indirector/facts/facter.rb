require 'puppet/node/facts'
require 'puppet/indirector/code'

class Puppet::Node::Facts::Facter < Puppet::Indirector::Code
  desc "Retrieve facts from Facter.  This provides a somewhat abstract interface
    between Puppet and Facter.  It's only `somewhat` abstract because it always
    returns the local host's facts, regardless of what you attempt to find."

  def allow_remote_requests?
    false
  end

  def destroy(facts)
    raise Puppet::DevError, _('You cannot destroy facts in the code store; it is only used for getting facts from Facter')
  end

  def save(facts)
    raise Puppet::DevError, _('You cannot save facts to the code store; it is only used for getting facts from Facter')
  end

  # Lookup a host's facts up in Facter.
  def find(request)
    Facter.reset

    # Note: we need to setup puppet's external search paths before adding the puppetversion
    # fact. This is because in Facter 2.x, the first `Facter.add` causes Facter to create
    # its directory loaders which cannot be changed, meaning other external facts won't
    # be resolved. (PUP-4607)
    self.class.setup_external_search_paths(request)
    self.class.setup_search_paths(request)

    # Initialize core Puppet facts, such as puppetversion
    Puppet.initialize_facts

    result = Puppet::Node::Facts.new(request.key, Facter.to_hash)
    result.add_local_facts
    result.sanitize
    result
  end

  def self.setup_search_paths(request)
    # Add any per-module fact directories to facter's search path
    dirs = request.environment.modulepath.collect do |dir|
      ['lib', 'plugins'].map do |subdirectory|
        Dir.glob("#{dir}/*/#{subdirectory}/facter")
      end
    end.flatten + Puppet[:factpath].split(File::PATH_SEPARATOR)

    dirs = dirs.select do |dir|
      next false unless FileTest.directory?(dir)

      # Even through we no longer directly load facts in the terminus,
      # print out each .rb in the facts directory as module
      # developers may find that information useful for debugging purposes
      if Puppet::Util::Log.sendlevel?(:info)
        Puppet.info _("Loading facts")
        Dir.glob("#{dir}/*.rb").each do |file|
          Puppet.debug "Loading facts from #{file}"
        end
      end

      true
    end

    Facter.search(*dirs)
  end

  def self.setup_external_search_paths(request)
    # Add any per-module external fact directories to facter's external search path
    dirs = []
    request.environment.modules.each do |m|
      if m.has_external_facts?
        dir = m.plugin_fact_directory
        Puppet.debug "Loading external facts from #{dir}"
        dirs << dir
      end
    end

    # Add system external fact directory if it exists
    if FileTest.directory?(Puppet[:pluginfactdest])
      dir = Puppet[:pluginfactdest]
      Puppet.debug "Loading external facts from #{dir}"
      dirs << dir
    end

    Facter.search_external dirs
  end
end
