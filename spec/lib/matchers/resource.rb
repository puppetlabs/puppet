module Matchers; module Resource
  extend RSpec::Matchers::DSL

  matcher :have_resource do |expected_resource|
    def resource_match(expected_resource, actual_resource)
      matched = true
      failures = []

      if actual_resource.ref != expected_resource
        matched = false
        failures << "expected #{expected_resource} but was #{actual_resource.ref}"
      end

      @params ||= {}
      @params.each do |name, value|
        case value
        when RSpec::Matchers::DSL::Matcher
          if !value.matches?(actual_resource[name])
            matched = false
            failures << "expected #{name} to match '#{value.description}' but was '#{actual_resource[name]}'"
          end
        else
          if actual_resource[name] != value
            matched = false
            failures << "expected #{name} to be '#{value}' but was '#{actual_resource[name]}'"
          end
        end
      end
      @mismatch = failures.join("\n")

      matched
    end

    match do |actual_catalog|
      @mismatch = ""
      if resource = actual_catalog.resource(expected_resource)
        resource_match(expected_resource, resource)
      else
        @mismatch = "expected #{@actual.to_dot} to include #{expected_resource}"
        false
      end
    end

    chain :with_parameter do |name, value|
      @params ||= {}
      @params[name] = value
    end

    def failure_message
      @mismatch
    end
  end


  matcher :be_resource do |expected_resource|
    def resource_match(expected_resource, actual_resource)
      if actual_resource.ref == expected_resource
        true
      else
        @mismatch = "expected #{expected_resource} but was #{actual_resource.ref}"
        false
      end
    end

    match do |actual_resource|
      resource_match(expected_resource, actual_resource)
    end

    def failure_message
      @mismatch
    end
  end

end; end
