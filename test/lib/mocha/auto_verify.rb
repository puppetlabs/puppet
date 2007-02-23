require 'mocha/mock'

# Methods added to TestCase allowing creation of mock objects.
#
# Mocks created this way will have their expectations automatically verified at the end of the test.
#
# See Mocha::MockMethods for methods on mock objects.
module Mocha
  
  module AutoVerify
  
    def mocks # :nodoc:
      @mocks ||= []
    end
  
    def reset_mocks # :nodoc:
      @mocks = nil
    end
    
    # :call-seq: mock(name) -> mock object
    #            mock(expected_methods = {}) -> mock object
    #            mock(name, expected_methods = {}) -> mock object
    #
    # Creates a mock object.
    #
    # +name+ is a +String+ identifier for the mock object.
    #
    # +expected_methods+ is a +Hash+ with expected method name symbols as keys and corresponding return values as values.
    #
    # Note that (contrary to expectations set up by #stub) these expectations <b>must</b> be fulfilled during the test.
    #   def test_product
    #     product = mock('ipod_product', :manufacturer => 'ipod', :price => 100)
    #     assert_equal 'ipod', product.manufacturer
    #     assert_equal 100, product.price
    #     # an error will be raised unless both Product#manufacturer and Product#price have been called
    #   end 
    def mock(*args)
      name, expectations = name_and_expectations_from_args(args)
      build_mock_with_expectations(:expects, expectations, name)
    end
  
    # :call-seq: stub(name) -> mock object
    #            stub(stubbed_methods = {}) -> mock object
    #            stub(name, stubbed_methods = {}) -> mock object
    #
    # Creates a mock object.
    #
    # +name+ is a +String+ identifier for the mock object.
    #
    # +stubbed_methods+ is a +Hash+ with stubbed method name symbols as keys and corresponding return values as values.
    #
    # Note that (contrary to expectations set up by #mock) these expectations <b>need not</b> be fulfilled during the test.
    #   def test_product
    #     product = stub('ipod_product', :manufacturer => 'ipod', :price => 100)
    #     assert_equal 'ipod', product.manufacturer
    #     assert_equal 100, product.price
    #     # an error will not be raised even if Product#manufacturer and Product#price have not been called
    #   end
    def stub(*args)
      name, expectations = name_and_expectations_from_args(args)
      build_mock_with_expectations(:stubs, expectations, name)
    end
  
    # :call-seq: stub_everything(name) -> mock object
    #            stub_everything(stubbed_methods = {}) -> mock object
    #            stub_everything(name, stubbed_methods = {}) -> mock object
    #
    # Creates a mock object that accepts calls to any method.
    #
    # By default it will return +nil+ for any method call.
    #
    # +name+ and +stubbed_methods+ work in the same way as for #stub.
    #   def test_product
    #     product = stub_everything('ipod_product', :price => 100)
    #     assert_nil product.manufacturer
    #     assert_nil product.any_old_method
    #     assert_equal 100, product.price
    #   end
    def stub_everything(*args)
      name, expectations = name_and_expectations_from_args(args)
      build_mock_with_expectations(:stub_everything, expectations, name)
    end
    
    def verify_mocks # :nodoc:
      mocks.each { |mock| mock.verify { yield if block_given? } }
    end

    def teardown_mocks # :nodoc:
      reset_mocks
    end
  
    def build_mock_with_expectations(expectation_type = :expects, expectations = {}, name = nil) # :nodoc:
      stub_everything = (expectation_type == :stub_everything)
      expectation_type = :stubs if expectation_type == :stub_everything
      mock = Mocha::Mock.new(stub_everything, name)
      expectations.each do |method, result|
        mock.__send__(expectation_type, method).returns(result)
      end
      mocks << mock
      mock
    end
    
  private

    def name_and_expectations_from_args(args) # :nodoc:
      name = args.first.is_a?(String) ? args.delete_at(0) : nil
      expectations = args.first || {}
      [name, expectations]
    end
  
  end
  
end