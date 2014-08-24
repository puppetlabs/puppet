module Matchers; module Resource
  extend RSpec::Matchers::DSL

  matcher :be_resource do |expected_resource|
    @params = {}

    match do |actual_resource|
      matched = true
      failures = []

      if actual_resource.ref != expected_resource
        matched = false
        failures << "expected #{expected_resource} but was #{actual_resource.ref}"
      end

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

    chain :with_parameter do |name, value|
      @params[name] = value
    end

    def failure_message_for_should
      @mismatch
    end
  end
  module_function :be_resource

  matcher :have_resource do |expected_resource|
    @params = {}
    @matcher = Matchers::Resource.be_resource(expected_resource)

    match do |actual_catalog|
      @mismatch = ""
      if resource = actual_catalog.resource(expected_resource)
        @matcher.matches?(resource)
      else
        @mismatch = "expected #{@actual.to_dot} to include #{@expected[0]}"
        false
      end
    end

    chain :with_parameter do |name, value|
      @matcher.with_parameter(name, value)
    end

    def failure_message_for_should
      @mismatch.empty? ? @matcher.failure_message_for_should : @mismatch
    end
  end
  module_function :have_resource
end; end
