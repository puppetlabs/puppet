test_name "C94788: exported resources using a yaml terminus for storeconfigs" do
require 'puppet/acceptance/environment_utils'
extend Puppet::Acceptance::EnvironmentUtils

tag 'audit:medium',
    'audit:integration',
    'audit:refactor',     # This could be a component of a larger workflow scenario.
    'server'

  # user resource doesn't have a provider on arista
  skip_test if agents.any? {|agent| agent['platform'] =~ /^eos/ } # see PUP-5404, ARISTA-42
  skip_test 'requires puppetserver to service restart' if @options[:type] != 'aio'

  app_type = File.basename(__FILE__, '.*')
  tmp_environment   = mk_tmp_environment_with_teardown(master, app_type)
  exported_username = 'er0ck'

  teardown do
    step 'stop puppet server' do
      on(master, "service #{master['puppetservice']} stop")
    end
    step 'remove cached agent pson catalogs from the master' do
      on(master, "rm -f #{File.join(master.puppet['yamldir'],'catalog','*')}",
         :accept_all_exit_codes => true)
    end
    on(master, "mv #{File.join('','tmp','puppet.conf')} #{master.puppet['confdir']}",
       :accept_all_exit_codes => true)
    step 'clean out collected resources' do
      on(hosts, puppet_resource("user #{exported_username} ensure=absent"), :accept_all_exit_codes => true)
    end
  end

  storeconfigs_backend_name = 'pson_storeconfigs'
  step 'create a yaml storeconfigs terminus in the modulepath' do
    moduledir = File.join(environmentpath,tmp_environment,'modules')
    terminus_class_name = 'PsonStoreconfigs'
    manifest = <<MANIFEST
File {
  ensure => directory,
}
file {
  '#{moduledir}':;
  '#{moduledir}/yaml_terminus':;
  '#{moduledir}/yaml_terminus/lib':;
  '#{moduledir}/yaml_terminus/lib/puppet':;
  '#{moduledir}/yaml_terminus/lib/puppet/indirector':;
  '#{moduledir}/yaml_terminus/lib/puppet/indirector/catalog':;
  '#{moduledir}/yaml_terminus/lib/puppet/indirector/facts':;
  '#{moduledir}/yaml_terminus/lib/puppet/indirector/node':;
  '#{moduledir}/yaml_terminus/lib/puppet/indirector/resource':;
}
file { '#{moduledir}/yaml_terminus/lib/puppet/indirector/catalog/#{storeconfigs_backend_name}.rb':
  ensure => file,
  content => '
    require "puppet/indirector/catalog/yaml"
    class Puppet::Resource::Catalog::#{terminus_class_name} < Puppet::Resource::Catalog::Yaml
      def save(request)
        raise ArgumentError.new("You can only save objects that respond to :name") unless request.instance.respond_to?(:name)
        file = path(request.key)
        basedir = File.dirname(file)
        # This is quite likely a bad idea, since we are not managing ownership or modes.
        Dir.mkdir(basedir) unless Puppet::FileSystem.exist?(basedir)
        begin
          # We cannot dump anonymous modules in yaml, so dump to json/pson
          File.open(file, "w") { |f| f.write request.instance.to_pson }
        rescue TypeError => detail
          Puppet.err "Could not save \#{self.name} \#{request.key}: \#{detail}"
        end
      end
      def find(request)
        nil
      end
    end
  ',
}
file { '#{moduledir}/yaml_terminus/lib/puppet/indirector/facts/#{storeconfigs_backend_name}.rb':
  ensure => file,
  content => '
    require "puppet/indirector/facts/yaml"
    class Puppet::Node::Facts::#{terminus_class_name} < Puppet::Node::Facts::Yaml
      def find(request)
        nil
      end
    end
  ',
}
file { '#{moduledir}/yaml_terminus/lib/puppet/indirector/node/#{storeconfigs_backend_name}.rb':
  ensure => file,
  content => '
    require "puppet/indirector/node/yaml"
    class Puppet::Node::#{terminus_class_name} < Puppet::Node::Yaml
      def find(request)
        nil
      end
    end
  ',
}
file { '#{moduledir}/yaml_terminus/lib/puppet/indirector/resource/#{storeconfigs_backend_name}.rb':
  ensure => file,
  content => '
    require "puppet/indirector/yaml"
    require "puppet/resource/catalog"
    class Puppet::Resource::#{terminus_class_name} < Puppet::Indirector::Yaml
      desc "Read resource instances from cached catalogs"
      def search(request)
        catalog_dir = File.join(Puppet.run_mode.master? ? Puppet[:yamldir] : Puppet[:clientyamldir], "catalog", "*")
        results = Dir.glob(catalog_dir).collect { |file|
          catalog = Puppet::Resource::Catalog.convert_from(:pson, File.read(file))
          if catalog.name == request.options[:host]
            next
          end
          catalog.resources.select { |resource|
            resource.type == request.key && resource.exported
          }.map! { |res|
            data_hash = res.to_data_hash
            parameters = data_hash["parameters"].map do |name, value|
              Puppet::Parser::Resource::Param.new(:name => name, :value => value)
            end
            attrs = {:parameters => parameters, :scope => request.options[:scope]}
            result = Puppet::Parser::Resource.new(res.type, res.title, attrs)
            result.collector_id = "\#{catalog.name}|\#{res.type}|\#{res.title}"
            result
          }
        }.flatten.compact
        results
      end
    end
  ',
}
# all the filtering is taken care of in the terminii
#   so any tests on filtering belong with puppetdb or pe
file { '#{environmentpath}/#{tmp_environment}/manifests/site.pp':
  ensure => file,
  content => '
    node "#{master.hostname}" {
      @@user{"#{exported_username}": ensure => present,}
    }
    node "default" {
      # collect resources on all nodes (puppet prevents collection on same node)
      User<<| |>>
    }
  ',
}
MANIFEST
    apply_manifest_on(master, manifest, :catch_failures => true)
  end

  # must specify environment in puppet.conf for it to pickup the terminus code in an environment module
  #   but we have to bounce the server to pickup the storeconfigs... config anyway
  # we can't use with_puppet_running_on here because it uses puppet resource to bounce the server
  #   puppet resource tries to use yaml_storeconfig's path() which doesn't exist
  #   and fails back to yaml which indicates an attempted directory traversal and fails.
  #   we could implemnt path() properly, but i'm just going to start the server the old fashioned way
  #  and... config set is broken and doesn't add a main section
  step 'turn on storeconfigs, start puppetserver the old fashioned way' do
    on(master, "cp #{File.join(master.puppet['confdir'],'puppet.conf')} #{File.join('','tmp')}")
    on(master, "echo [main] >> #{File.join(master.puppet['confdir'],'puppet.conf')}")
    on(master, "echo environment=#{tmp_environment} >> #{File.join(master.puppet['confdir'],'puppet.conf')}")
    on(master, puppet('config set storeconfigs true --section main'))
    on(master, puppet("config set storeconfigs_backend #{storeconfigs_backend_name} --section main"))
    on(master, "service #{master['puppetservice']} restart")
    step 'run the master agent to export the resources' do
      on(master, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment}"))
    end
    agents.each do |agent|
      next if agent == master
      step 'run the agents to collect exported resources' do
        on(agent, puppet("agent -t --server #{master.hostname} --environment #{tmp_environment}"),
           :acceptable_exit_codes => 2)
        on(agent, puppet_resource("user #{exported_username}"), :accept_all_exit_codes => true) do |result|
          assert_match(/present/, result.stdout, 'collected resource not found')
        end
      end
    end
  end

end
