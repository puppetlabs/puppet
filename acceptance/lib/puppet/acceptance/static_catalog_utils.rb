module Puppet
  module Acceptance
    module StaticCatalogUtils

      # Adds code-id-command and code-content-command scripts
      # to the server and updates puppetserver.conf. This is
      # necessary for testing static catalogs.
      # @param master [String] the host running puppetserver.
      # @param scriptdir [String] the path to the directory where the scripts should be placed.
      def setup_puppetserver_code_id_scripts(master, scriptdir)
        code_id_command = <<EOF
#! /bin/bash

echo -n 'code_version_1'
EOF

        code_content_command = <<EOF
#! /bin/bash

if [ \\\$2 == 'code_version_1' ] ; then
  echo -n 'code_version_1'
else
  echo -n 'newer_code_version'
fi
EOF
        apply_manifest_on(master, <<MANIFEST, :catch_failures => true)
file { '#{scriptdir}/code_id.sh':
  ensure => file,
  content => "#{code_id_command}",
  mode => "0755",
}

file { '#{scriptdir}/code_content.sh':
  ensure => file,
  content => "#{code_content_command}",
  mode => "0755",
}
MANIFEST

        puppetserver_config = "#{master['puppetserver-confdir']}/puppetserver.conf"
        on master, "cp #{puppetserver_config} #{scriptdir}/puppetserver.conf.bak"
        versioned_code_settings = {"versioned-code" => {"code-id-command" => "#{scriptdir}/code_id.sh", "code-content-command" => "#{scriptdir}/code_content.sh"}}
        modify_tk_config(master, puppetserver_config, versioned_code_settings)
      end

      def cleanup_puppetserver_code_id_scripts(master, scriptdir)
        # These are -f so we don't bail on the teardown if for some reason they didn't get laid down
        on master, "rm -f #{scriptdir}/code_id.sh"
        on master, "rm -f #{scriptdir}/code_content.sh"
        puppetserver_config = "#{master['puppetserver-confdir']}/puppetserver.conf"
        on master, "cp #{scriptdir}/puppetserver.conf.bak #{puppetserver_config}"
      end
    end
  end
end
