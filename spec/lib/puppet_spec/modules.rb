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

      Puppet::Module.new(name, :environment => environment, :path => module_dir)
    end

    # Return path to temparory directory for testing.
    def testdir
      return @testdir ||= tmpdir("module_tool_testdir")
    end

    # Create a temporary testing directory, change into it, and execute the
    # +block+. When the block exists, remove the test directory and change back
    # to the previous directory.
    def mktestdircd(&block)
      previousdir = Dir.pwd
      rmtestdir
      FileUtils.mkdir_p(testdir)
      Dir.chdir(testdir)
      block.call
    ensure
      rmtestdir
      Dir.chdir previousdir
    end

    # Remove the temporary test directory.
    def rmtestdir
      FileUtils.rm_rf(testdir) if File.directory?(testdir)
    end
    # END helper methods

  end
end
