module Matchers; module Resource
  extend RSpec::Matchers::DSL

  matcher :have_resource do |expected_resource|
    @params = {}

    match do |actual_catalog|
      @mismatch = ""
      if resource = actual_catalog.resource(expected_resource)
        matched = true
        failures = []
        @params.each do |name, value|
          if resource[name] != value
            matched = false
            failures << "expected #{name} to be '#{value}' but was '#{resource[name]}'"
          end
        end
        @mismatch = failures.join("\n")

        matched
      else
        @mismatch = "expected #{@actual.to_dot} to include #{@expected[0]}"
        false
      end
    end

    chain :with_parameter do |name, value|
      @params[name] = value
    end

    def failure_message_for_should
      @mismatch
    end
  end
end; end
