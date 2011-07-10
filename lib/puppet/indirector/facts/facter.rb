require 'puppet/node/facts'
require 'puppet/indirector/code'

class Puppet::Node::Facts::Facter < Puppet::Indirector::Code
  desc "Retrieve facts from Facter.  This provides a somewhat abstract interface
    between Puppet and Facter.  It's only `somewhat` abstract because it always
    returns the local host's facts, regardless of what you attempt to find."


  def initialize(*args)
    super
    self.load()
  end

  def destroy(facts)
    raise Puppet::DevError, "You cannot destroy facts in the code store; it is only used for getting facts from Facter"
  end

  # Look a host's facts up in Facter.
  def find(request)
    result = Puppet::Node::Facts.new(request.key, Facter.to_hash)

    result.add_local_facts
    result.stringify
    result.downcase_if_necessary

    result
  end

  # Load all facts, both in plugins and from Facter.
  # This is a public method that other back-ends should implement.
  def load
    # First clear and load everything that ships with Facter
    Facter.clear
    Facter.loadfacts

    # Then all of the facts in Puppet plugin dirs
    module_fact_dirs = Puppet[:modulepath].split(":").collect do |d|
      ["lib", "plugins"].map do |subdirectory|
        Dir.glob("#{d}/*/#{subdirectory}/facter")
      end
    end.flatten
    dirs = module_fact_dirs + Puppet[:factpath].split(File::PATH_SEPARATOR)
    x = dirs.each do |dir|
      load_facts_in_dir(dir)
    end
  end

  def load_facts_in_dir(dir)
    return unless FileTest.directory?(dir)

    Dir.chdir(dir) do
      Dir.glob("*.rb").each do |file|
        fqfile = ::File.join(dir, file)
        begin
          Puppet.info "Loading facts in #{::File.basename(file.sub(".rb",''))}"
          Timeout::timeout(self.timeout) do
            Kernel.load(file)
          end
        rescue SystemExit,NoMemoryError
          raise
        rescue Exception => detail
          puts detail.backtrace if Puppet[:trace]
          Puppet.warning "Could not load fact file #{fqfile}: #{detail}"
        end
      end
    end
  end

  def save(facts)
    raise Puppet::DevError, "You cannot save facts to the code store; it is only used for getting facts from Facter"
  end

  def timeout
    timeout = Puppet[:configtimeout]
    case timeout
    when String
      if timeout =~ /^\d+$/
        timeout = Integer(timeout)
      else
        raise ArgumentError, "Configuration timeout must be an integer"
      end
    when Integer # nothing
    else
      raise ArgumentError, "Configuration timeout must be an integer"
    end

    timeout
  end
end
