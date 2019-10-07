module Puppet
  module Acceptance
    module BeakerUtils
      # TODO: This should be added to Beaker
      def assert_matching_arrays(expected, actual, message = "")
        assert_equal(expected.sort, actual.sort, message)
      end

      # TODO: Remove the wrappers to user_present
      # and user_absent if Beaker::Host's user_present
      # and user_absent functions are fixed to work with
      # Arista (EOS).

      def user_present(host, username)
        case host['platform']
        when /eos/
          on(host, "useradd #{username}")
        else
          host.user_present(username)
        end
      end

      def user_absent(host, username)
        case host['platform']
        when /eos/
          on(host, "userdel #{username}", acceptable_exit_codes: [0, 1])
        else
          host.user_absent(username)
        end
      end
    end

    module PackageUtils
      def package_present(host, package, version = nil)
          host.install_package(package, '', version)
      end

      def package_absent(host, package, cmdline_args = '', opts = {})
          host.uninstall_package(package, cmdline_args, opts)
      end
    end

    module CommandUtils
      def ruby_command(host)
        "env PATH=\"#{host['privatebindir']}:${PATH}\" ruby"
      end
      module_function :ruby_command

      def gem_command(host, type='aio')
        if type == 'aio'
          if host['platform'] =~ /windows/
            "env PATH=\"#{host['privatebindir']}:${PATH}\" cmd /c gem"
          else
            "env PATH=\"#{host['privatebindir']}:${PATH}\" gem"
          end
        else
          on(host, 'which gem').stdout.chomp
        end
      end
      module_function :gem_command
    end

    module ManifestUtils
      def resource_manifest(resource, title, params = {})
        params_str = params.map do |param, value|
          # This is not quite correct for all parameter values,
          # but it is good enough for most purposes.
          value_str = value.to_s
          value_str = "\"#{value_str}\"" if value.is_a?(String)

          "  #{param} => #{value_str}"
        end.join(",\n")

        <<-MANIFEST
#{resource} { '#{title}':
  #{params_str}
}
MANIFEST
      end

      def file_manifest(path, params = {})
        resource_manifest('file', path, params)
      end

      def user_manifest(username, params = {})
        resource_manifest('user', username, params)
      end
    end
  end
end
