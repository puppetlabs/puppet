module PuppetSpec::Modules
  class << self
    def create(name, dir, options = {})
      module_dir = File.join(dir, name)
      FileUtils.mkdir_p(module_dir)

      environment = options[:environment]

      if metadata = options[:metadata]
        metadata[:source]  ||= 'github'
        metadata[:author]  ||= 'puppetlabs'
        metadata[:version] ||= '9.9.9'
        metadata[:license] ||= 'to kill'
        metadata[:dependencies] ||= []

        metadata[:name] = "#{metadata[:author]}/#{name}"

        File.open(File.join(module_dir, 'metadata.json'), 'w') do |f|
          f.write(metadata.to_json)
        end
      end

      if tasks = options[:tasks]
        tasks_dir = File.join(module_dir, 'tasks')
        FileUtils.mkdir_p(tasks_dir)
        tasks.each do |task_files|
          task_files.each do |task_file|
            FileUtils.touch(File.join(tasks_dir, task_file))
          end
        end
      end

      Puppet::Module.new(name, module_dir, environment)
    end

    def generate_files(name, dir, options = {})
      module_dir = File.join(dir, name)
      FileUtils.mkdir_p(module_dir)

      if metadata = options[:metadata]
        File.open(File.join(module_dir, 'metadata.json'), 'w') do |f|
          f.write(metadata.to_json)
        end
      end
    end
  end
end
