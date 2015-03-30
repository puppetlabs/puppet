test_name "Lookup data using the agnostic lookup function"
# pre-docs:
# http://puppet-on-the-edge.blogspot.com/2015/01/puppet-40-data-in-modules-and.html

testdir = master.tmpdir('lookup')

step 'Setup'

module_name                     = "data_module"
module_name2                    = "other_module"
hash_name                       = "hash_name"
array_key                       = "array_key"

env_data_implied_key            = "env_data_implied"
env_data_implied_value          = "env_implied_a"
env_data_key                    = "env_data"
env_data_value                  = "env_a"
env_hash_key                    = "env_hash_key"
env_hash_value                  = "env_class_a"
env_array_value0                = "env_array_a"
env_array_value1                = "env_array_b"

module_data_implied_key         = "module_data_implied"
module_data_implied_value       = "module_implied_b"
module_data_key                 = "module_data"
module_data_value               = "module_b"
module_data_value_other         = "other_module_b"
module_hash_key                 = "module_hash_key"
module_hash_value               = "module_class_b"
module_array_value0             = "module_array_a"
module_array_value1             = "module_array_b"

env_data_override_implied_key   = "env_data_override_implied"
env_data_override_implied_value = "env_override_implied_c"
env_data_override_key           = "env_data_override"
env_data_override_value         = "env_override_c"

hiera_data_implied_key          = "apache_server_port_implied"
hiera_data_implied_value        = "8080"
hiera_data_key                  = "apache_server_port"
hiera_data_value                = "9090"
hiera_hash_key                  = "hiera_hash_key"
hiera_hash_value                = "hiera_class_c"
hiera_array_value0              = "hiera_array_a"
hiera_array_value1              = "hiera_array_b"


def mod_manifest_entry(module_name = nil, testdir, module_data_implied_key,
                       module_data_implied_value, module_data_key,
                       module_data_value, hash_name, module_hash_key,
                       module_hash_value, array_key, module_array_value0,
                       module_array_value1)
  if module_name
    module_files_manifest = <<PP
      # the binding to specify the function to provide data for this module
      file { '#{testdir}/environments/production/modules/#{module_name}/lib/puppet/bindings/#{module_name}/default.rb':
        ensure => file,
        content => "
          Puppet::Bindings.newbindings('#{module_name}::default') do
            # In the default bindings for this module
            bind {
              # bind its name to the 'puppet' module data provider
              name         '#{module_name}'
              to           'function'
              in_multibind 'puppet::module_data'
           }
          end
        ",
        mode => "0640",
      }

      # the function to provide data for this module
      file { '#{testdir}/environments/production/modules/#{module_name}/lib/puppet/functions/#{module_name}/data.rb':
        ensure => file,
        content => "
          Puppet::Functions.create_function(:'#{module_name}::data') do
            def data()
              { '#{module_name}::#{module_data_implied_key}' => '#{module_data_implied_value}',
                '#{module_name}::#{module_data_key}' => '#{module_data_value}',
                '#{module_name}::#{hash_name}' => {'#{module_hash_key}' => '#{module_hash_value}'},
                '#{module_name}::#{array_key}' => ['#{module_array_value0}', '#{module_array_value1}']
              }
            end
          end
        ",
        mode => "0640",
      }
PP
    module_files_manifest
  end
end

module_manifest1 = mod_manifest_entry(module_name, testdir, module_data_implied_key,
                       module_data_implied_value, module_data_key, module_data_value,
                       hash_name, module_hash_key, module_hash_value, array_key,
                       module_array_value0, module_array_value1)
module_manifest2 = mod_manifest_entry(module_name2, testdir, module_data_implied_key,
                       module_data_implied_value, module_data_key, module_data_value_other,
                       hash_name, module_hash_key, module_hash_value, array_key,
                       module_array_value0, module_array_value1)

apply_manifest_on(master, <<-PP, :catch_failures => true)
File {
  ensure => directory,
  mode => "0750",
  owner => #{master.puppet['user']},
  group => #{master.puppet['group']},
}

file {
  '#{testdir}':;
  '#{testdir}/hieradata':;
  '#{testdir}/environments':;
  '#{testdir}/environments/production':;
  '#{testdir}/environments/production/manifests':;
  '#{testdir}/environments/production/modules':;
  '#{testdir}/environments/production/lib':;
  '#{testdir}/environments/production/lib/puppet':;
  '#{testdir}/environments/production/lib/puppet/functions':;
  '#{testdir}/environments/production/lib/puppet/functions/environment':;
  '#{testdir}/environments/production/modules/#{module_name}':;
  '#{testdir}/environments/production/modules/#{module_name}/manifests':;
  '#{testdir}/environments/production/modules/#{module_name}/lib':;
  '#{testdir}/environments/production/modules/#{module_name}/lib/puppet':;
  '#{testdir}/environments/production/modules/#{module_name}/lib/puppet/bindings':;
  '#{testdir}/environments/production/modules/#{module_name}/lib/puppet/bindings/#{module_name}':;
  '#{testdir}/environments/production/modules/#{module_name}/lib/puppet/functions':;
  '#{testdir}/environments/production/modules/#{module_name}/lib/puppet/functions/#{module_name}':;
  '#{testdir}/environments/production/modules/#{module_name2}':;
  '#{testdir}/environments/production/modules/#{module_name2}/manifests':;
  '#{testdir}/environments/production/modules/#{module_name2}/lib':;
  '#{testdir}/environments/production/modules/#{module_name2}/lib/puppet':;
  '#{testdir}/environments/production/modules/#{module_name2}/lib/puppet/bindings':;
  '#{testdir}/environments/production/modules/#{module_name2}/lib/puppet/bindings/#{module_name2}':;
  '#{testdir}/environments/production/modules/#{module_name2}/lib/puppet/functions':;
  '#{testdir}/environments/production/modules/#{module_name2}/lib/puppet/functions/#{module_name2}':;
}

file { '#{testdir}/hiera.yaml':
  ensure  => file,
  content => '---
    :backends:
      - "yaml"
    :logger: "console"
    :hierarchy:
      - "global"

    :yaml:
      :datadir: "#{testdir}/hieradata"
  ',
  mode => "0640",
}

file { '#{testdir}/hieradata/global.yaml':
  ensure  => file,
  content => "---
    #{hiera_data_key}: #{hiera_data_value}
    #{module_name}::#{hiera_data_implied_key}: #{hiera_data_implied_value}
    #{module_name}::#{hash_name}:
        #{hiera_hash_key}: #{hiera_hash_value}
    #{module_name}::#{array_key}:
        - #{hiera_array_value0}
        - #{hiera_array_value1}
  ",
  mode => "0640",
}

file { '#{testdir}/environments/production/environment.conf':
  ensure => file,
  content => '
    environment_timeout = 0
    # for this environment, provide our own function to supply data to lookup
    # implies a ruby function in <environment>/lib/puppet/functions/environment/data.rb
    #   named environment::data()
    environment_data_provider = "function"
  ',
  mode => "0640",
}

# the function to provide data for this environment
file { '#{testdir}/environments/production/lib/puppet/functions/environment/data.rb':
  ensure => file,
  content => "
    Puppet::Functions.create_function(:'environment::data') do
      def data()
        { '#{module_name}::#{env_data_implied_key}' => '#{env_data_implied_value}',
          '#{module_name}::#{env_data_override_implied_key}' => '#{env_data_override_implied_value}',
          '#{env_data_key}' => '#{env_data_value}',
          '#{module_name}::#{hash_name}' => {'#{env_hash_key}' => '#{env_hash_value}'},
          '#{env_data_override_key}' => '#{env_data_override_value}',
          '#{module_name}::#{array_key}' => ['#{env_array_value0}', '#{env_array_value1}']
        }
      end
    end
  ",
  mode => "0640",
}

# place module file segments here
#{module_manifest1}
# same key, different module and values
#{module_manifest2}

file { '#{testdir}/environments/production/modules/#{module_name}/manifests/init.pp':
  ensure => file,
  content => '
    class #{module_name}($#{env_data_implied_key},
                         $#{module_data_implied_key},
                         $#{env_data_override_implied_key},
                         $#{hiera_data_implied_key}) {
      # lookup data from the environment function databinding
      notify { "#{env_data_implied_key} $#{env_data_implied_key}": }
      $lookup_env = lookup("#{env_data_key}")
      notify { "#{env_data_key} $lookup_env": }

      # lookup data from the module databinding
      notify { "#{module_data_implied_key} $#{module_data_implied_key}": }
      $lookup_module = lookup("#{module_name}::#{module_data_key}")
      notify { "#{module_data_key} $lookup_module": }

      # lookup data from another modules databinding
      $lookup_module2 = lookup("#{module_name2}::#{module_data_key}")
      notify { "#{module_data_key} $lookup_module2": }

      # ensure env can override module
      notify { "#{env_data_override_implied_key} $#{env_data_override_implied_key}": }
      $lookup_override = lookup("#{env_data_override_key}")
      notify { "#{env_data_override_key} $lookup_override": }

      # should fall-back to hiera global.yaml data
      notify { "#{hiera_data_implied_key} $#{hiera_data_implied_key}": }
      $lookup_port = lookup("#{hiera_data_key}")
      notify { "#{hiera_data_key} $lookup_port": }

      # should be able to merge hashes across sources
      #   this mimicks/covers behavior for including classes
      $lookup_hash = lookup("#{module_name}::#{hash_name}",Hash[String,String],\\'hash\\')
      notify { "#{hash_name} $lookup_hash": }

      # should be able to make an array across sources
      #   this mimicks/covers behavior for including classes
      $lookup_array = lookup("#{module_name}::#{array_key}",Array[String],\\'unique\\')
      notify { "yep": message => "#{array_key} $lookup_array" }
    }',
  mode => "0640",
}

file { '#{testdir}/environments/production/manifests/site.pp':
  ensure => file,
  content => "
    node default {
      include #{module_name}
    }",
  mode => "0640",
}
PP

step "Try to lookup string data"

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
    'hiera_config' => "#{testdir}/hiera.yaml",
  },
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    on(agent, puppet('agent', "-t --server #{master}"), :acceptable_exit_codes => [2])
    assert_match("#{env_data_implied_key} #{env_data_implied_value}", stdout)
    assert_match("#{env_data_key} #{env_data_value}", stdout)

    assert_match("#{module_data_implied_key} #{module_data_implied_value}", stdout)
    assert_match("#{module_data_key} #{module_data_value}", stdout)

    assert_match("#{module_data_key} #{module_data_value_other}", stdout)

    assert_match("#{env_data_override_implied_key} #{env_data_override_implied_value}", stdout)
    assert_match("#{env_data_override_key} #{env_data_override_value}", stdout)

    assert_match("#{hiera_data_implied_key} #{hiera_data_implied_value}", stdout)
    assert_match("#{hiera_data_key} #{hiera_data_value}", stdout)

    assert_match("#{hash_name} {#{module_hash_key} => #{module_hash_value}, #{env_hash_key} => #{env_hash_value}, #{hiera_hash_key} => #{hiera_hash_value}}", stdout)

    assert_match("#{array_key} [#{hiera_array_value0}, #{hiera_array_value1}, #{env_array_value0}, #{env_array_value1}, #{module_array_value0}, #{module_array_value1}]", stdout)
  end
end
