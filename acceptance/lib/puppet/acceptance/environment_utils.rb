require 'puppet/acceptance/module_utils'

module Puppet
  module Acceptance
    module EnvironmentUtils
      include Puppet::Acceptance::ModuleUtils

      # Generate puppet manifest for the creation of an environment with
      # the given modulepath and manifest and env_name.  The created environment
      # will have on testing_mod module, and manifest site.pp which includes it.
      #
      # @param options [Hash<Sym,String>]
      # @option options [String] :modulepath Modules directory
      # @option options [String] :manifest Manifest directory
      # @option options [String] :env_name Environment name
      # @return [String] Puppet manifest to create the environment files
      def generate_environment(options)
        modulepath = options[:modulepath]
        manifestpath = options[:manifestpath]
        env_name = options[:env_name]

        <<-MANIFEST_SNIPPET
          file {
            ###################################################
            # #{env_name}
        #{generate_module("testing_mod", env_name, modulepath)}

            "#{manifestpath}":;
            "#{manifestpath}/site.pp":
              ensure => file,
              mode => "0640",
              content => '
                notify { "in #{env_name} site.pp": }
                include testing_mod
              '
            ;
          }
        MANIFEST_SNIPPET
      end

      # Generate one module's manifest code.
      def generate_module(module_name, env_name, modulepath)
        <<-MANIFEST_SNIPPET
            "#{modulepath}":;
            "#{modulepath}/#{module_name}":;
            "#{modulepath}/#{module_name}/manifests":;

            "#{modulepath}/#{module_name}/manifests/init.pp":
              ensure => file,
              mode => "0640",
              content => 'class #{module_name} {
                notify { "include #{env_name} #{module_name}": }
              }'
            ;
        MANIFEST_SNIPPET
      end

      # Default, legacy, dynamic and directory environments
      # using generate_manifest(), all rooted in testdir.
      #
      # @param [String] testdir path to the temp directory which will be the confdir all
      #   the environments live in
      # @return [String] Puppet manifest to generate all of the environment files.
      def environment_manifest(testdir)
        <<-MANIFEST
          File {
            ensure => directory,
            owner => #{master.puppet['user']},
            group => #{master.puppet['group']},
            mode => "0750",
          }

          file { "#{testdir}": }

        #{generate_environment(
            :modulepath => "#{testdir}/modules",
            :manifestpath => "#{testdir}/manifests",
            :env_name => "default environment")}

        #{generate_environment(
            :modulepath => "#{testdir}/testing-modules",
            :manifestpath => "#{testdir}/testing-manifests",
            :env_name => "legacy testing environment")}

          file {
            "#{testdir}/dynamic":;
            "#{testdir}/dynamic/testing":;
          }

        #{generate_environment(
            :modulepath => "#{testdir}/dynamic/testing/modules",
            :manifestpath => "#{testdir}/dynamic/testing/manifests",
            :env_name => "dynamic testing environment")}

          file {
            "#{testdir}/environments":;
            "#{testdir}/environments/testing":;
          }

        #{generate_environment(
            :modulepath => "#{testdir}/environments/testing/modules",
            :manifestpath => "#{testdir}/environments/testing/manifests",
            :env_name => "directory testing environment")}

          file {
            "#{testdir}/environments/testing_environment_conf":;
          }

        #{generate_environment(
            :modulepath => "#{testdir}/environments/testing_environment_conf/nonstandard-modules",
            :manifestpath => "#{testdir}/environments/testing_environment_conf/nonstandard-manifests",
            :env_name => "directory testing with environment.conf")}

          file { "#{testdir}/environments/testing_environment_conf/environment.conf":
            ensure => file,
            mode => "0640",
            content => '
              modulepath = nonstandard-modules:$basemodulepath
              manifest = nonstandard-manifests
              config_version = local-version.sh
            '
          }

          file {
            "#{testdir}/environments/testing_environment_conf/local-version.sh":
              ensure => file,
              mode => "0640",
              content => '#! /usr/bin/env bash
              echo "local testing_environment_conf"'
            ;
          }

          ###################
          # Services

          file {
            "#{testdir}/services":;
            "#{testdir}/services/testing":;
        #{generate_module('service_mod',
                            "service testing environment",
                            "#{testdir}/services/testing/modules")}
          }

          #######################
          # Config version script

          file {
            "#{testdir}/static-version.sh":
              ensure => file,
              mode => "0640",
              content => '#! /usr/bin/env bash
              echo "static"'
            ;
          }
        MANIFEST
      end

      def get_directory_hash_from(host, path)
        dir_hash = {}
        on(host, "ls #{path}") do |result|
          result.stdout.split.inject(dir_hash) do |hash,f|
            hash[f] = "#{path}/#{f}"
            hash
          end
        end
        dir_hash
      end

      def safely_shadow_directory_contents_and_yield(host, original_path, new_path, &block)
        original_files = get_directory_hash_from(host, original_path)
        new_files = get_directory_hash_from(host, new_path)
        conflicts = original_files.keys & new_files.keys

        step "backup original files" do
          conflicts.each do |c|
            on(host, "mv #{original_files[c]} #{original_files[c]}.bak")
          end
        end

        step "shadow original files with temporary files" do
          new_files.each do |name,full_path_name|
            on(host, "cp -R #{full_path_name} #{original_path}/#{name}")
          end
        end

        new_file_list = new_files.keys.map { |name| "#{original_path}/#{name}" }.join(' ')
        step "open permissions to 755 on all temporary files copied into working dir and set ownership" do
          on(host, "chown -R #{host.puppet['user']}:#{host.puppet['group']} #{new_file_list}")
          on(host, "chmod -R 755 #{new_file_list}")
        end

        if host.check_for_command("selinuxenabled")
          result = on(host, "selinuxenabled", :acceptable_exit_codes => [0,1])

          if result.exit_code == 0
            step "mirror selinux contexts" do
              context = on(host, "matchpathcon #{original_path}").stdout.chomp.split(' ')[1]
              on(host, "chcon -R #{context} #{new_file_list}")
            end
          end
        end

        yield

      ensure
        step "clear out the temporary files" do
          files_to_delete = new_files.keys.map { |name| "#{original_path}/#{name}" }
          on(host, "rm -rf #{files_to_delete.join(' ')}")
        end
        step "move the shadowed files back to their original places" do
          conflicts.each do |c|
            on(host, "mv #{original_files[c]}.bak #{original_files[c]}")
          end
        end
      end

      # Stand up a puppet master on the master node with the given master_opts
      # using the passed envdir as the source of the puppet environment files,
      # and passed confdir as the directory to use for the temporary
      # puppet.conf. It then runs through a series of environment tests for the
      # passed environment and returns a hashed structure of the results.
      #
      # @return [Hash<Beaker::Host,Hash<Sym,Beaker::Result>>] Hash of
      #   Beaker::Hosts for each agent run keyed to a hash of Beaker::Result
      #   objects keyed by each subtest that was performed.
      def use_an_environment(environment, description, master_opts, envdir, confdir, options = {})
        master_puppet_conf = master_opts.dup # shallow clone

        results = {}
        safely_shadow_directory_contents_and_yield(master, puppet_config(master, 'codedir', section: 'master'), envdir) do
          config_print = options[:config_print]
          directory_environments = options[:directory_environments]

          with_puppet_running_on(master, master_puppet_conf, confdir) do
            agents.each do |agent|
              agent_results = results[agent] = {}

              step "puppet agent using #{description} environment"
              args = "-t", "--server", master
              args << ["--environment", environment] if environment
              # Test agents configured to use directory environments (affects environment
              # loading on the agent, especially with regards to requests/node environment)
              args << "--environmentpath='$confdir/environments'" if directory_environments && agent != master
              on(agent, puppet("agent", *args), :acceptable_exit_codes => (0..255)) do
                agent_results[:puppet_agent] = result
              end

              args = ["--trace"]
              args << ["--environment", environment] if environment

              step "print puppet config for #{description} environment"
              on(master, puppet(*(["config", "print", "basemodulepath", "modulepath", "manifest", "config_version", config_print] + args)), :acceptable_exit_codes => (0..255)) do
                agent_results[:puppet_config] = result
              end

              step "puppet apply using #{description} environment"
              on(master, puppet(*(["apply", '-e', '"include testing_mod"'] + args)), :acceptable_exit_codes => (0..255)) do
                agent_results[:puppet_apply] = result
              end

              # Be aware that Puppet Module Tool will create the module directory path if it
              # does not exist.  So these tests should be run last...
              step "install a module into environment"
              on(master, puppet(*(["module", "install", "pmtacceptance-nginx"] + args)), :acceptable_exit_codes => (0..255)) do
                agent_results[:puppet_module_install] = result
              end

              step "uninstall a module from #{description} environment"
              on(master, puppet(*(["module", "uninstall", "pmtacceptance-nginx"] + args)), :acceptable_exit_codes => (0..255)) do
                agent_results[:puppet_module_uninstall] = result
              end
            end
          end
        end

        return results
      end

      # For each Beaker::Host in the results Hash, generates a chart, comparing
      # the expected exit code and regexp matches from expectations to the
      # Beaker::Result.output for a particular command that was executed in the
      # environment.  Outputs either 'ok' or text highlighting the errors, and
      # returns false if any errors were found.
      #
      # @param [Hash<Beaker::Host,Hash<Sym,Beaker::Result>>] results
      # @param [Hash<Sym,Hash{Sym => Integer,Array<Regexp>}>] expectations
      # @return [Array] Returns an empty array of there were no failures, or an
      #   Array of failed cases.
      def review_results(results, expectations)
        failed = []

        results.each do |agent, agent_results|
          divider = "-" * 79

          logger.info divider
          logger.info "For: (#{agent.name}) #{agent}"
          logger.info divider

          agent_results.each do |testname, execution_results|
            expected_exit_code = expectations[testname][:exit_code]
            match_tests = expectations[testname][:matches] || []
            not_match_tests = expectations[testname][:does_not_match] || []
            expect_failure = expectations[testname][:expect_failure]
            notes = expectations[testname][:notes]

            errors = []

            if execution_results.exit_code != expected_exit_code
              errors << "To exit with an exit code of '#{expected_exit_code}', instead of '#{execution_results.exit_code}'"
            end

            match_tests.each do |regexp|
              if execution_results.output !~ regexp
                errors << "#{errors.empty? ? "To" : "And"} match: #{regexp}"
              end
            end

            not_match_tests.each do |regexp|
              if execution_results.output =~ regexp
                errors << "#{errors.empty? ? "Not to" : "And not"} match: #{regexp}"
              end
            end

            error_msg = "Expected the output:\n#{execution_results.output}\n#{errors.join("\n")}" unless errors.empty?

            case_failed = case
              when errors.empty? && expect_failure then 'ok - failed as expected'
              when errors.empty? && !expect_failure then 'ok'
              else '*UNEXPECTED FAILURE*'
            end
            logger.info "#{testname}: #{case_failed}"
            if case_failed == 'ok - failed as expected'
              logger.info divider
              logger.info "Case is known to fail as follows:\n#{execution_results.output}\n"
            elsif case_failed == '*UNEXPECTED FAILURE*'
              failed << "Unexpected failure for #{testname}"
              logger.info divider
              logger.info "#{error_msg}"
            end

            logger.info("------\nNotes: #{notes}") if notes
            logger.info divider
          end
        end

        return failed
      end

      def assert_review(review)
        failures = []
        review.each do |failed|
          if !failed.empty?
            problems = "Problems in the output reported above:\n  #{failed}"
            logger.warn(problems)
            failures << problems
          end
        end
        assert failures.empty?, "Failed Review:\n\n#{failures.join("\n")}\n"
      end

      # generate a random string of 6 letters and numbers.  NOT secure
      def random_string
        [*('a'..'z'),*('0'..'9')].shuffle[0,8].join
      end
      private :random_string

      # if the first test to call this has changed the environmentpath, this will cause trouble
      #   maybe not the best idea to memoize this?
      def environmentpath
        @@memoized_environmentpath ||= master.puppet['environmentpath']
      end
      module_function :environmentpath

      # create a tmpdir to hold a temporary environment bound by puppet environment naming restrictions
      # symbolically link environment into environmentpath
      # we can't use the temp_file utils in our own lib because host.tmpdir violates puppet's naming requirements
      # in rare cases we want to do this on agents when testing things that use the default manifest
      def mk_tmp_environment_with_teardown(host, environment)
        # add the tmp_environment to a set to ensure no collisions
        @@tmp_environment_set ||= Set.new
        deadman = 100; loop_num = 0
        while @@tmp_environment_set.include?(tmp_environment = environment.downcase + '_' + random_string) do
          break if (loop_num = loop_num + 1) > deadman
        end
        @@tmp_environment_set << tmp_environment
        tmpdir = File.join('','tmp',tmp_environment)
        on host, "mkdir -p #{tmpdir}/manifests #{tmpdir}/modules; chmod -R 755 #{tmpdir}"

        # register teardown to remove the link below
        teardown do
          on host, "rm -rf #{File.join(environmentpath,tmp_environment)}"
        end

        # WARNING: this won't work with filesync (symlinked environments are not supported)
        on host, "mkdir -p #{environmentpath}; ln -sf #{tmpdir} #{File.join(environmentpath,tmp_environment)}"
        return tmp_environment
      end
      module_function :mk_tmp_environment_with_teardown

      # create sitepp in a tmp_environment as created by mk_tmp_environment_with_teardown
      def create_sitepp(host, tmp_environment, file_content)
        file_path = File.join('','tmp',tmp_environment,'manifests','site.pp')
        create_remote_file(host, file_path, file_content)
        on host, "chmod -R 755 #{file_path}"
      end

    end
  end
end
