require 'puppet/face'

Puppet::Face.define(:environment, '0.0.1') do
  copyright "Puppet Labs", 2014
  license   "Apache 2 license; see COPYING"

  summary "Provides interaction with directory environments."
  description <<-EOT
  This command helps with management of directory based environments, notably listing them or flushing the puppet master
  internal cache of directory environments set to 'manual'.
  EOT

  action :list do
    summary "List all directory environments."
    returns "the list of all directory environments"
    description <<-EOT
    Lists all directory environments.
    EOT
    examples <<-EOT
      Lists all directory environments:

      $ puppet environment list
    EOT

    option "--details" do
      summary "displays more information about the listed environments"
    end

    when_invoked do |options|
      setup_environments do
        Puppet.lookup(:environments).list.each do |env|
          unless options[:details]
            puts env.name
          else
            unless Puppet.lookup(:environments).get_environment_dir(env.name).nil?
              conf = Puppet.lookup(:environments).get_conf(env.name)
              puts "#{env.name} (timeout: #{Puppet::Settings::TTLSetting.unmunge(conf.environment_timeout, 'environment_timeout')}, manifest: #{conf.manifest}, modulepath: #{conf.modulepath})"
            end
          end
        end
      end
      nil
    end
  end

  action :flush do
    summary "Flushes the cache of directory environments set to 'manual'."
    arguments "[<environment> [<environment> ...]]"
    returns "Nothing."
    description <<-EOT
    Flushes the given environment cache. With --all it is possible to flush all directory environments.
    EOT
    examples <<-EOT
      Manually flush the usdatacenter environment:

      $ puppet environment flush usdatacenter

      Manually flush all environments:

      $ puppet environment flush --all

      Manually flush several environments:

      $ puppet environment flush env1 env2 env3
    EOT

    option "--all" do
      summary "force all directory environments set to 'manual' to be invalidated"
    end

    when_invoked do |*args|
      options = args.pop
      name = args

      setup_environments do
        envs = options[:all] ? Puppet.lookup(:environments).list.map(&:name) : [name].flatten
        envs.each do |envname|
          if dir = Puppet.lookup(:environments).get_environment_dir(envname)
            Puppet::FileSystem.touch(dir)
          end
        end
      end
      nil
    end
  end

  def setup_environments
    # pretend we're the master
    master_section = Puppet.settings.values(nil, :master)

    loader_settings = {
      :environmentpath => master_section.interpolate(:environmentpath),
      :basemodulepath => master_section.interpolate(:basemodulepath),
    }
    Puppet.override(Puppet.base_context(loader_settings),
                   "New environment loaders generated from the requested section.") do
      yield
    end
  end

end