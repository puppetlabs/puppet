module Puppet
  module Acceptance
    module CommonTests
      # This module contains common tests for the attributes property, which is
      # used by AIX and Windows in the User resource and AIX in the Group
      # resource.
      module AttributesProperty
        def to_kv_array(attributes)
          attributes.map { |attribute, value| "#{attribute}=#{value}" }
        end

        def assert_attributes_on(host, expected_attributes, current_attributes, message = "")
          expected_attributes.each do |attribute, value|
            attribute_str = "attributes[#{attribute}]"
            actual_value = current_attributes[attribute]
            assert_match(
              /\A#{value}\z/,
              actual_value,
              "EXPECTED: #{attribute_str} = \"#{value}\", ACTUAL:  #{attribute_str} = \"#{actual_value}\" -- #{message}"
            )
          end
        end
  
        def assert_puppet_changed_attributes(result, resource, name, changed_attributes)
          stdout = result.stdout.chomp
          changed_attributes.each do |attribute, value|
            prefix = /#{resource}\[#{name}\].*attributes changed.*/
            attribute_str = "attributes[#{name}][#{attribute}]"
      
            assert_match(
              /#{prefix}#{attribute}=#{value}/,
              stdout,
              "Puppet did not indicate that #{attribute_str} changed to #{value}"
            )
          end
        end
  
        # Runs a common set of tests for the attributes property on the given
        # host. Note that current_attributes_on is a lambda that retrieves the
        # current attributes of the given resource instance resource_name on the
        # host. It is invoked as
        #          current_attributes_on.call(host, resource_name)
        #
        # The resource_name parameter is the name of the resource instance
        # that will be created. Note that it is the caller's responsibility
        # to ensure that this resource is deleted.
        def run_common_attributes_property_tests_on(
          host,
          resource,
          resource_name,
          current_attributes_on,
          initial_attributes,
          changed_attributes
        )
          attributes = initial_attributes.dup
  
          step "Ensure that the #{resource} can be created with the specified attributes" do
            manifest = resource_manifest(
              resource,
              resource_name,
              ensure: :present,
              attributes: to_kv_array(attributes)
            )
  
            apply_manifest_on(host, manifest)
            assert_attributes_on(host, attributes, current_attributes_on.call(host, resource_name), "Puppet fails to create the user with the specified attributes")
          end
  
          step "Ensure that Puppet noops when the specified attributes are already set" do
            manifest = resource_manifest(
              resource,
              resource_name,
              attributes: to_kv_array(attributes)
            )
  
            apply_manifest_on(host, manifest, catch_changes: true)
          end
  
          # Remember the changed attribute's old values
          old_attributes = attributes.select { |k, _| changed_attributes.keys.include?(k) }
  
          step "Ensure that Puppet updates only the specified attributes and nothing else" do
            attributes = attributes.merge(changed_attributes)
      
            manifest = resource_manifest(
              resource,
              resource_name,
              attributes: to_kv_array(attributes)
            )
      
            apply_manifest_on(host, manifest) do |result|
              assert_puppet_changed_attributes(
                result,
                resource.capitalize,
                resource_name,
                changed_attributes
              )
            end
            assert_attributes_on(host, attributes, current_attributes_on.call(host, resource_name), "Puppet fails to update the specified attributes")
          end
  
          step "Ensure that Puppet accepts a hash for the attributes property" do
            # We want to see if Puppet will do something with the attributes property
            # when we pass it in as a hash so that it does not just pass validation
            # and end up noop-ing. Let's set our attributes back to what they used to
            # be. This is also a postcondition of the tests.
            attributes.merge(old_attributes)
  
            manifest = resource_manifest(
              resource,
              resource_name,
              attributes: attributes
            )
  
            apply_manifest_on(host, manifest)
            assert_attributes_on(host, attributes, current_attributes_on.call(host, resource_name), "Puppet does not accept a hash for the attributes property.")
          end
  
          step "Ensure that `puppet resource #{resource}` outputs valid Puppet code" do
            on(host, puppet("resource #{resource} #{resource_name}")) do |result|
              manifest = result.stdout.chomp
              apply_manifest_on(host, manifest)
            end
          end
        end
      end
    end
  end
end
