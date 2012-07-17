module Puppet
  module DSL

    ##
    # BlankSlate is a class intended for use with +method_missing+.
    # Ruby 1.9 version is based on BasicObject.
    # Ruby 1.8 version has almost all methods undefined.
    #
    # Ruby 1.9 version doesn't include Kernel module.
    # To reference a constant in that version +::+ has to be prepended to
    # constant name.
    ##
    if RUBY_VERSION < "1.9"
      ##
      # Ruby 1.8 version
      ##
      class BlankSlate
        ##
        # Undefine all methods but those defined in BasicObject.
        ##
        instance_methods.each do |m|
          unless ['==', 'equal?', '!', '!=', 'instance_eval', 'instance_exec',
            '__send__', '__id__'].include? m
            undef_method m
          end
        end
      end
    else
      ##
      # Ruby 1.9 version
      ##
      class BlankSlate < BasicObject; end
    end

    ##
    # Reopening class to add methods.
    ##
    class BlankSlate

      ##
      # Redefine method from Object, as BasicObject doesn't include it.
      # It is used to define a singleton method on Context to cache
      # +method_missing+ calls.
      ##
      private
      def define_singleton_method(name, &block)
        class << self; self; end.instance_eval do
          define_method name, &block
        end
      end
    end

  end
end

