module PuppetSpec::Modules
  class << self
    def create(name, dir, options = {})
      module_dir = File.join(dir, name)
      FileUtils.mkdir_p(module_dir)

      environment = Puppet::Node::Environment.new(options[:environment])

      if metadata = options[:metadata]
        metadata[:source]  ||= 'github'
        metadata[:author]  ||= 'puppetlabs'
        metadata[:version] ||= '9.9.9'
        metadata[:license] ||= 'to kill'
        metadata[:dependencies] ||= []

        metadata[:name] = "#{metadata[:author]}/#{name}"

        File.open(File.join(module_dir, 'metadata.json'), 'w') do |f|
          f.write(metadata.to_pson)
        end
      end

      Puppet::Module.new(name, module_dir, environment)
    end
  end
end
