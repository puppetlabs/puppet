module Spec
  module Mocks
    module SpecMethods
      include Spec::Mocks::ArgumentConstraintMatchers

      # Shortcut for creating an instance of Spec::Mocks::Mock.
      def mock(name, options={})
        Spec::Mocks::Mock.new(name, options)
      end

      # Shortcut for creating an instance of Spec::Mocks::Mock with
      # predefined method stubs.
      #
      # == Examples
      #
      #   stub_thing = stub("thing", :a => "A")
      #   stub_thing.a == "A" => true
      #
      #   stub_person = stub("thing", :name => "Joe", :email => "joe@domain.com")
      #   stub_person.name => "Joe"
      #   stub_person.email => "joe@domain.com"
      def stub(name, stubs={})
        object_stub = mock(name)
        stubs.each { |key, value| object_stub.stub!(key).and_return(value) }
        object_stub
      end
      
    end
  end
end
