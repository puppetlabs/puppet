require 'puppet/acceptance/environment_utils'

module Puppet
  module Acceptance
    module PuppetTypeTestTools
      include Puppet::Acceptance::EnvironmentUtils # for now, just for #random_string

      # FIXME: yardocs
      # TODO: create resource class which contains its manifest chunk, and assertions
      #   can be an array or singular, holds the manifest and the assertion_code
      #   has getter for the manifest
      #   has #run_assertions(BeakerResult or string)
      def generate_manifest(test_resources)
        manifest = ''
        test_resources = [test_resources].flatten # ensure it's an array so we enumerate properly
        test_resources.each do |resource|
          manifest << resource[:pre_code] + "\n" if resource[:pre_code]
          namevar = (resource[:parameters][:namevar] if resource[:parameters]) || "#{resource[:type]}_#{random_string}"
          # ensure these are double quotes around the namevar incase users puppet-interpolate inside it
          # FIXME: add test ^^
          manifest << resource[:type] + '{"' + namevar + '":' if resource[:type]
          if resource[:parameters]
            resource[:parameters].each do |key,value|
              next if key == :namevar
              manifest << "#{key} => #{value},"
            end
          end
          manifest << "}\n" if resource[:type]
        end
        return manifest
      end

      def generate_assertions(test_resources)
        assertion_code = ''
        test_resources = [test_resources].flatten # ensure it's an array so we enumerate properly
        test_resources.each do |resource|
          if resource[:assertions]
            resource[:assertions] = [resource[:assertions]].flatten # ensure it's an array so we enumerate properly
            resource[:assertions].each do |assertion_type|
              expect_failure = false
              if assertion_type[:expect_failure]
                expect_failure = true
                assertion_code << "expect_failure '#{assertion_type[:expect_failure][:message]}' do\n"
                # delete the message
                assertion_type[:expect_failure].delete(:message)
                # promote the hash in expect_failure
                assertion_type = assertion_type[:expect_failure]
                assertion_type.delete(:expect_failure)
              end

              # ensure all the values are arrays
              assertion_values = [assertion_type.values].flatten
              assertion_values.each do |assertion_value|
                # TODO: non matching asserts?
                # TODO: non stdout? (support stdout, stderr, exit_code)
                # TODO: what about checking resource state on host (non agent/apply #on use)?
                if assertion_type.keys.first =~ /assert_match/
                  assert_msg = 'found '
                elsif assertion_type.keys.first =~ /refute_match/
                  assert_msg = 'did not find '
                else
                  assert_msg = ''
                end
                if assertion_value.is_a?(String)
                  matcher = "\"#{assertion_value}\""
                elsif assertion_value.is_a?(Regexp)
                  matcher = assertion_value.inspect
                else
                  matcher = assertion_value
                end
                assertion_code << "#{assertion_type.keys.first}(#{matcher}, result.stdout, '#{assert_msg}#{matcher}')\n"
              end

              assertion_code << "end\n" if expect_failure
            end
          end
        end
        return assertion_code
      end

      Result = Struct.new(:stdout)
      def run_assertions(assertions = '', result)
        result_struct = Result.new
        if result.respond_to? :stdout
          result_struct.stdout = result.stdout
        else
          # handle results sent in as string
          result_struct.stdout = result
        end
        result = result_struct

        begin
          eval(assertions)
        rescue RuntimeError, SyntaxError => e
          puts e
          puts assertions
          raise
        end
      end

    end
  end
end
