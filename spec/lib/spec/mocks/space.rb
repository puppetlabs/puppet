module Spec
  module Mocks
    class Space
      def add(obj)
        mocks << obj unless mocks.include?(obj)
      end

      def verify_all
        mocks.each do |mock|
          mock.rspec_verify
        end
      end
      
      def reset_all
        mocks.each do |mock|
          mock.rspec_reset
        end
        mocks.clear
      end
      
    private
    
      def mocks
        @mocks ||= []
      end
    end
  end
end
