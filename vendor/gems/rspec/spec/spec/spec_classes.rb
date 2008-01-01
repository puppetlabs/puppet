# This file contains various classes used by the specs.
module Spec
  module Expectations
    class Person
      attr_reader :name
      def initialize name
        @name = name
      end
      def == other
        return @name == other.name
      end
    end
    
    class ClassWithMultiWordPredicate
      def multi_word_predicate?
        true 
      end
    end

    module Helper
      class CollectionWithSizeMethod
        def initialize; @list = []; end
        def size; @list.size; end
        def push(item); @list.push(item); end
      end

      class CollectionWithLengthMethod
        def initialize; @list = []; end
        def length; @list.size; end
        def push(item); @list.push(item); end
      end

      class CollectionOwner
        attr_reader :items_in_collection_with_size_method, :items_in_collection_with_length_method

        def initialize
          @items_in_collection_with_size_method = CollectionWithSizeMethod.new
          @items_in_collection_with_length_method = CollectionWithLengthMethod.new
        end

        def add_to_collection_with_size_method(item)
          @items_in_collection_with_size_method.push(item)
        end

        def add_to_collection_with_length_method(item)
          @items_in_collection_with_length_method.push(item)
        end
        
        def items_for(arg)
          return [1, 2, 3] if arg == 'a'
          [1]
        end
        
      end

      class HandCodedMock
        include Spec::Matchers
        def initialize(return_val)
          @return_val = return_val
          @funny_called = false
        end

        def funny?
          @funny_called = true
          @return_val
        end

        def hungry?(a, b, c)
          a.should equal(1)
          b.should equal(2)
          c.should equal(3)
          @funny_called = true
          @return_val
        end
        
        def exists?
          @return_val
        end
        
        def multi_word_predicate?
          @return_val
        end

        def rspec_verify
          @funny_called.should be_true
        end
      end
      class ClassWithUnqueriedPredicate
        attr_accessor :foo
        def initialize(foo)
          @foo = foo
        end
      end
    end
  end
end

module Custom
  class Formatter < Spec::Runner::Formatter::BaseTextFormatter
    attr_reader :where
    
    def initialize(where)
      @where = where
    end
  end

  class BadFormatter < Spec::Runner::Formatter::BaseTextFormatter
    attr_reader :where
    
    def initialize(where)
      bad_method
    end
  end

  class BehaviourRunner
    def initialize(options, arg=nil); end
  end
end

