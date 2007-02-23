require 'mocha/mock_methods'

module Mocha

  class Mock
    
    include MockMethods

    def initialize(stub_everything = false, name = nil)
      @stub_everything = stub_everything
      @mock_name = name
    end

    def mocha_inspect
      @mock_name ? "#<Mock:#{@mock_name}>" : "#<Mock:0x#{__id__.to_s(16)}>"
    end

  end

end