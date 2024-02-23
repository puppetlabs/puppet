# frozen_string_literal: true

require_relative '../../../puppet/node/facts'
require_relative '../../../puppet/indirector/code'

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
    Puppet.runtime[:facter].reset

    # Note: we need to setup puppet's external search paths before adding the puppetversion
    # fact. This is because in Facter 2.x, the first `Puppet.runtime[:facter].add` causes Facter to create
    # its directory loaders which cannot be changed, meaning other external facts won't
    # be resolved. (PUP-4607)
    self.class.setup_external_search_paths(request)
    self.class.setup_search_paths(request)

    # Initialize core Puppet facts, such as puppetversion
    Puppet.initialize_facts

    result = if request.options[:resolve_options]
               raise(Puppet::Error, _("puppet facts show requires version 4.0.40 or greater of Facter.")) unless Facter.respond_to?(:resolve)

               find_with_options(request)
             elsif Puppet[:include_legacy_facts]
               # to_hash returns both structured and legacy facts
               Puppet::Node::Facts.new(request.key, Puppet.runtime[:facter].to_hash)
             else
               # resolve does not return legacy facts unless requested
               facts = Puppet.runtime[:facter].resolve('')
               # some versions of Facter 4 return a Facter::FactCollection instead of
               # a Hash, breaking API compatibility, so force a hash using `to_h`
               Puppet::Node::Facts.new(request.key, facts.to_h)
             end

    result.add_local_facts unless request.options[:resolve_options]
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
          Puppet.debug { "Loading facts from #{file}" }
        end
      end

      true
    end
    dirs << request.options[:custom_dir] if request.options[:custom_dir]
    Puppet.runtime[:facter].search(*dirs)
  end

  def self.setup_external_search_paths(request)
    # Add any per-module external fact directories to facter's external search path
    dirs = []
    request.environment.modules.each do |m|
      next unless m.has_external_facts?

      dir = m.plugin_fact_directory
      Puppet.debug { "Loading external facts from #{dir}" }
      dirs << dir
    end

    # Add system external fact directory if it exists
    if FileTest.directory?(Puppet[:pluginfactdest])
      dir = Puppet[:pluginfactdest]
      Puppet.debug { "Loading external facts from #{dir}" }
      dirs << dir
    end

    dirs << request.options[:external_dir] if request.options[:external_dir]
    Puppet.runtime[:facter].search_external dirs
  end

  private

  def find_with_options(request)
    options = request.options
    options_for_facter = ''.dup
    options_for_facter += options[:user_query].join(' ')
    options_for_facter += " --config #{options[:config_file]}" if options[:config_file]
    options_for_facter += " --show-legacy" if options[:show_legacy]
    options_for_facter += " --no-block" if options[:no_block] == false
    options_for_facter += " --no-cache" if options[:no_cache] == false
    options_for_facter += " --timing" if options[:timing]

    Puppet::Node::Facts.new(request.key, Puppet.runtime[:facter].resolve(options_for_facter))
  end
end
