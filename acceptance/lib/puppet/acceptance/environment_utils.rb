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

        environment = <<-MANIFEST_SNIPPET
          file {
            ###################################################
            # #{env_name}
        #{generate_module("testing_mod", env_name, modulepath)}

            "#{manifestpath}":;
            "#{manifestpath}/site.pp":
              ensure => file,
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
        module_pp = <<-MANIFEST_SNIPPET
            "#{modulepath}":;
            "#{modulepath}/#{module_name}":;
            "#{modulepath}/#{module_name}/manifests":;

            "#{modulepath}/#{module_name}/manifests/init.pp":
              ensure => file,
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
        manifest = <<-MANIFEST
          File {
            ensure => directory,
            owner => puppet,
            mode => 0700,
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
            content => '
              modulepath = nonstandard-modules:$basemodulepath
              manifest = nonstandard-manifests
              config_version = local-version.sh
            '
          }

          file {
            "#{testdir}/environments/testing_environment_conf/local-version.sh":
              ensure => file,
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
              content => '#! /usr/bin/env bash
              echo "static"'
            ;
          }
        MANIFEST
      end

      # Stand up a puppet master on the master node with the given master_opts
      # using the passed confdir as the --confdir setting, and then run through a
      # series of environment tests for the passed environment and return a hashed
      # structure of the results.
      #
      # @return [Hash<Beaker::Host,Hash<Sym,Beaker::Result>>] Hash of
      #   Beaker::Hosts for each agent run keyed to a hash of Beaker::Result
      #   objects keyed by each subtest that was performed.
      def use_an_environment(environment, description, master_opts, confdir, options = {})
        ssldir = on(master, puppet("master --configprint ssldir")).stdout.chomp
        master_puppet_conf = master_opts.dup # shallow clone
        master_puppet_conf[:__commandline_args__] = "--confdir=#{confdir} --ssldir=#{ssldir}"
        config_print = options[:config_print]
        directory_environments = options[:directory_environments]
        results = {}

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

            if agent == master
              args = ["--trace", "--confdir", confdir]
              args << ["--environment", environment] if environment

              step "print puppet config for #{description} environment"
              on(agent, puppet(*(["config", "print", "basemodulepath", "modulepath", "manifest", "config_version", config_print] + args)), :acceptable_exit_codes => (0..255)) do
                agent_results[:puppet_config] = result
              end

              step "puppet apply using #{description} environment"
              on(agent, puppet(*(["apply", '-e', '"include testing_mod"'] + args)), :acceptable_exit_codes => (0..255)) do
                agent_results[:puppet_apply] = result
              end

              # Be aware that Puppet Module Tool will create the module directory path if it
              # does not exist.  So these tests should be run last...
              step "install a module into environment"
              on(agent, puppet(*(["module", "install", "pmtacceptance-nginx"] + args)), :acceptable_exit_codes => (0..255)) do
                agent_results[:puppet_module_install] = result
              end

              step "uninstall a module from #{description} environment"
              on(agent, puppet(*(["module", "uninstall", "pmtacceptance-nginx"] + args)), :acceptable_exit_codes => (0..255)) do
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
        review.each do |scenario, failed|
          if !failed.empty?
            problems = "Problems in the '#{scenario}' output reported above:\n  #{failed.join("\n  ")}"
            logger.warn(problems)
            failures << problems
          end
        end
        assert failures.empty?, "Failed Review:\n\n#{failures.join("\n")}\n"
      end
    end
  end
end
