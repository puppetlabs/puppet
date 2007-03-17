module Spec
  module Expectations
    module Should
      class Have
        def initialize(target, relativity=:exactly, expected=nil)
          @target = target
          init_collection_handler(target, relativity, expected)
          init_item_handler(target)
        end
        
        def init_collection_handler(target, relativity, expected)
          @collection_handler = CollectionHandler.new(target, relativity, expected)
        end
        
        def init_item_handler(target)
          @item_handler = PositiveItemHandler.new(target)
        end
    
        def method_missing(sym, *args)
          if @collection_handler.wants_to_handle(sym)
            @collection_handler.handle_message(sym, *args)
          elsif @item_handler.wants_to_handle(sym)
            @item_handler.handle_message(sym, *args)
          else
            Spec::Expectations.fail_with("target does not respond to #has_#{sym}?")
          end
        end
      end
      
      class NotHave < Have
        def init_item_handler(target)
          @item_handler = NegativeItemHandler.new(target)
        end
      end
      
      class CollectionHandler
        def initialize(target, relativity=:exactly, expected=nil)
          @target = target
          @expected = expected == :no ? 0 : expected
          @at_least = (relativity == :at_least)
          @at_most = (relativity == :at_most)
        end
        
        def at_least(expected_number=nil)
          @at_least = true
          @at_most = false
          @expected = expected_number == :no ? 0 : expected_number
          self
        end

        def at_most(expected_number=nil)
          @at_least = false
          @at_most = true
          @expected = expected_number == :no ? 0 : expected_number
          self
        end

        def method_missing(sym, *args)
          if @target.respond_to?(sym)
            handle_message(sym, *args)
          end
        end

        def wants_to_handle(sym)
          respond_to?(sym) || @target.respond_to?(sym)
        end

        def handle_message(sym, *args)
          return at_least(args[0]) if sym == :at_least
          return at_most(args[0]) if sym == :at_most
          Spec::Expectations.fail_with(build_message(sym, args)) unless as_specified?(sym, args)
        end

        def build_message(sym, args)
          message = "expected"
          message += " at least" if @at_least
          message += " at most" if @at_most
          message += " #{@expected} #{sym}, got #{actual_size_of(collection(sym, args))}"
        end

        def as_specified?(sym, args)
          return actual_size_of(collection(sym, args)) >= @expected if @at_least
          return actual_size_of(collection(sym, args)) <= @expected if @at_most
          return actual_size_of(collection(sym, args)) == @expected
        end

        def collection(sym, args)
          @target.send(sym, *args)
        end
    
        def actual_size_of(collection)
          return collection.length if collection.respond_to? :length
          return collection.size if collection.respond_to? :size
        end
      end
      
      class ItemHandler
        def wants_to_handle(sym)
          @target.respond_to?("has_#{sym}?")
        end

        def initialize(target)
          @target = target
        end

        def fail_with(message)
          Spec::Expectations.fail_with(message)
        end
      end
      
      class PositiveItemHandler < ItemHandler
        def handle_message(sym, *args)
          fail_with(
          "expected #has_#{sym}?(#{args.collect{|arg| arg.inspect}.join(', ')}) to return true, got false"
          ) unless @target.send("has_#{sym}?", *args)
        end
      end
      
      class NegativeItemHandler < ItemHandler
        def handle_message(sym, *args)
          fail_with(
          "expected #has_#{sym}?(#{args.collect{|arg| arg.inspect}.join(', ')}) to return false, got true"
          ) if @target.send("has_#{sym}?", *args)
        end
      end
    end
  end
end
