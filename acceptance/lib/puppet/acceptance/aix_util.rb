module Puppet
  module Acceptance
    module AixUtil
      def to_kv_array(attributes)
        attributes.map { |attribute, value| "#{attribute}=#{value}" }
      end

      def assert_object_attributes_on(host, object_get, object, expected_attributes)
        host.send(object_get, object) do |result|
          actual_attrs_kv_pairs = result.stdout.chomp.split(' ')[(1..-1)]
          actual_attrs = actual_attrs_kv_pairs.map do |kv_pair|
            attribute, value = kv_pair.split('=')
            next nil unless value
            [attribute, value]
          end.compact.to_h

          expected_attributes.each do |attribute, value|
            attribute_str = "attributes[#{object}][#{attribute}]"
            actual_value = actual_attrs[attribute]
            assert_match(
              /\A#{value}\z/,
              actual_value,
              "EXPECTED: #{attribute_str} = \"#{value}\", ACTUAL:  #{attribute_str} = \"#{actual_value}\""
            )
          end
        end
      end

      def assert_puppet_changed_object_attributes(result, object_resource, object, changed_attributes)
        stdout = result.stdout.chomp
        changed_attributes.each do |attribute, value|
          prefix = /#{object_resource}\[#{object}\].*attributes changed.*/
          attribute_str = "attributes[#{object}][#{attribute}]"
    
          assert_match(
            /#{prefix}#{attribute}=#{value}/,
            stdout,
            "Puppet did not indicate that #{attribute_str} changed to #{value}"
          )
        end
      end

      def object_resource_manifest(object_resource, object, params)
        params_str = params.map do |param, value|
          value_str = value.to_s
          value_str = "\"#{value_str}\"" if value.is_a?(String)
    
          "  #{param} => #{value_str}"
        end.join(",\n")
    
        <<-MANIFEST
#{object_resource} { '#{object}':
  #{params_str}
}
MANIFEST
      end

      def run_attribute_management_tests(object_resource, id_property, initial_attributes, changed_attributes)
        object_get = "#{object_resource}_get".to_sym
        object_absent = "#{object_resource}_absent".to_sym
        
        name = "obj"
        teardown do
          agents.each { |agent| agent.send(object_absent, name) }
        end

        current_attributes = initial_attributes.dup

        agents.each do |agent|
          agent.send(object_absent, name)

          # We extract the code for this step as a lambda because we will be checking
          # for this case (1) Before the object has been created and (2) After the
          # object has been created (towards the end). We do this because in (1), Puppet
          # does not trigger the property setters after creating the object, while in (2)
          # it does. These are two different scenarios that we want to check.
          step_run_errors_when_property_is_passed_as_attribute = lambda do
            manifest = object_resource_manifest(
              object_resource,
              name,
              attributes: current_attributes.merge({ 'id' => '15' })
            )
     
            apply_manifest_on(agent, manifest) do |result|
              assert_match(/Error:.*'#{id_property}'.*'id'/, result.stderr, "specifying a Puppet property as part of an AIX attribute should have errored, but received #{result.stderr}")
            end
          end

  
          step "Ensure that Puppet errors if a Puppet property is passed in as an AIX attribute when creating the #{object_resource}" do
            step_run_errors_when_property_is_passed_as_attribute.call
          end
      
          step "Ensure that the #{object_resource} can be created with the specified attributes" do
            manifest = object_resource_manifest(
              object_resource,
              name,
              ensure: :present,
              attributes: to_kv_array(current_attributes)
            )

            apply_manifest_on(agent, manifest)
            assert_object_attributes_on(agent, object_get, name, current_attributes)
          end

          step "Ensure that Puppet noops when the specified attributes are already set" do
            manifest = object_resource_manifest(
              object_resource,
              name,
              attributes: to_kv_array(current_attributes)
            )

            apply_manifest_on(agent, manifest, catch_changes: true)
          end

          # Remember the changed attribute's old values
          old_attributes = current_attributes.select { |k, _| changed_attributes.keys.include?(k) }

          step "Ensure that Puppet updates only the specified attributes and nothing else" do
            current_attributes = current_attributes.merge(changed_attributes)
      
            manifest = object_resource_manifest(
              object_resource,
              name,
              attributes: to_kv_array(current_attributes)
            )
      
            apply_manifest_on(agent, manifest) do |result|
              assert_puppet_changed_object_attributes(
                result,
                object_resource.capitalize,
                name,
                changed_attributes
              )
            end
            assert_object_attributes_on(agent, object_get, name, current_attributes)
          end

          step "Ensure that Puppet accepts a hash for the attributes property" do
            # We want to see if Puppet will do something with the attributes property
            # when we pass it in as a hash so that it does not just pass validation
            # and end up noop-ing. Let's set one of our attributes back to its old
            # value in order to simulate an actual change.
            attribute = old_attributes.keys.first
            old_value = old_attributes.delete(attribute)
            current_attributes[attribute] = old_value

            manifest = object_resource_manifest(
              object_resource,
              name,
              attributes: current_attributes
            )

            apply_manifest_on(agent, manifest)
            assert_object_attributes_on(agent, object_get, name, current_attributes)
          end

          step "Ensure that `puppet resource #{object_resource}` outputs valid Puppet code" do
            on(agent, puppet("resource #{object_resource} #{name}")) do |result|
              manifest = result.stdout.chomp
              apply_manifest_on(agent, manifest)
            end
          end

          step "Ensure that Puppet errors if a Puppet property is passed in as an AIX attribute after #{object_resource} has been created" do
            step_run_errors_when_property_is_passed_as_attribute.call
          end
        end
      end
    end
  end
end
