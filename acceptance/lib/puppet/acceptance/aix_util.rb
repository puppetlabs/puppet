module Puppet
  module Acceptance
    module AixUtil
      require 'puppet/acceptance/common_utils.rb'
      include Puppet::Acceptance::ManifestUtils

      def object_attributes_on(host, object_get, object)
        current_attributes = {}
        host.send(object_get, object) do |result|
          current_attributes_kv_pairs = result.stdout.chomp.split(' ')[(1..-1)]
          current_attributes = current_attributes_kv_pairs.map do |kv_pair|
            attribute, value = kv_pair.split('=')
            next nil unless value
            [attribute, value]
          end.compact.to_h
        end

        current_attributes
      end

      # Be sure to require puppet/acceptance/common_tests.rb and then extend
      # Puppet::Acceptance::CommonTests::AttributesProperty in your test file
      # before invoking this function.
      def run_aix_attribute_property_tests_on(
        agent,
        object_resource,
        id_property,
        initial_attributes,
        changed_attributes
      )
        object_get = "#{object_resource}_get".to_sym
        object_absent = "#{object_resource}_absent".to_sym
        
        name = "pl#{rand(999999).to_i}"
        teardown { agent.send(object_absent, name) }

        agent.send(object_absent, name)

        # We extract the code for this step as a lambda because we will be checking
        # for this case (1) Before the object has been created and (2) After the
        # object has been created (towards the end). We do this because in (1), Puppet
        # does not trigger the property setters after creating the object, while in (2)
        # it does. These are two different scenarios that we want to check.
        step_run_errors_when_property_is_passed_as_attribute = lambda do
          manifest = resource_manifest(
            object_resource,
            name,
            attributes: initial_attributes.merge({ 'id' => '15' })
          )
   
          apply_manifest_on(agent, manifest) do |result|
            assert_match(/Error:.*'#{id_property}'.*'id'/, result.stderr, "specifying a Puppet property as part of an AIX attribute should have errored, but received #{result.stderr}")
          end
        end

        step "Ensure that Puppet errors if a Puppet property is passed in as an AIX attribute when creating the #{object_resource}" do
          step_run_errors_when_property_is_passed_as_attribute.call
        end

        current_attributes_on = lambda { |host, username| object_attributes_on(host, object_get, username) }
        run_common_attributes_property_tests_on(
          agent,
          object_resource,
          name,
          current_attributes_on,
          initial_attributes,
          changed_attributes
        )

        step "Ensure that Puppet errors if a Puppet property is passed in as an AIX attribute after #{object_resource} has been created" do
          step_run_errors_when_property_is_passed_as_attribute.call
        end
      end
    end
  end
end
