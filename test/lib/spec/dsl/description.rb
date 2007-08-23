module Spec
  module DSL
    class Description
      module ClassMethods
        def generate_description(*args)
          description = args.shift.to_s
          unless args.empty?
            suffix = args.shift.to_s
            description << " " unless suffix =~ /^\s|\.|#/
            description << suffix
          end
          description
        end
      end
      extend ClassMethods

      attr_reader :description, :described_type
      
      def initialize(*args)
        args, @options = args_and_options(*args)
        init_behaviour_type(@options)
        init_spec_path(@options)
        init_described_type(args)
        init_description(*args)
      end
  
      def [](key)
        @options[key]
      end
      
      def []=(key, value)
        @options[key] = value
      end
      
      def to_s; @description; end
      
      def ==(value)
        case value
        when Description
          @description == value.description
        else
          @description == value
        end
      end
      
    private
      def init_behaviour_type(options)
        # NOTE - BE CAREFUL IF CHANGING THIS NEXT LINE:
        #   this line is as it is to satisfy JRuby - the original version
        #   read, simply: "if options[:behaviour_class]", which passed against ruby, but failed against jruby
        if options[:behaviour_class] && options[:behaviour_class].ancestors.include?(Behaviour)
          options[:behaviour_type] = parse_behaviour_type(@options[:behaviour_class])
        end
      end
      
      def init_spec_path(options)
        if options.has_key?(:spec_path)
          options[:spec_path] = File.expand_path(@options[:spec_path])
        end
      end
      
      def init_description(*args)
        @description = self.class.generate_description(*args)
      end
      
      def init_described_type(args)
        @described_type = args.first unless args.first.is_a?(String)
      end
    
      def parse_behaviour_type(behaviour_class)
        behaviour_class.to_s.split("::").reverse[0].gsub!('Behaviour', '').downcase.to_sym
      end

    end
  end
end
