module Spec
  module DSL
    class BehaviourFactory

      class << self

        BEHAVIOUR_CLASSES = {:default => Spec::DSL::Behaviour}
        
        # Registers a behaviour class +klass+ with the symbol
        # +behaviour_type+. For example:
        #
        #   Spec::DSL::BehaviourFactory.add_behaviour_class(:farm, Spec::Farm::DSL::FarmBehaviour)
        #
        # This will cause Kernel#describe from a file living in 
        # <tt>spec/farm</tt> to create behaviour instances of type
        # Spec::Farm::DSL::FarmBehaviour.
        def add_behaviour_class(behaviour_type, klass)
          BEHAVIOUR_CLASSES[behaviour_type] = klass
        end

        def remove_behaviour_class(behaviour_type)
          BEHAVIOUR_CLASSES.delete(behaviour_type)
        end

        def create(*args, &block)
          opts = Hash === args.last ? args.last : {}
          if opts[:shared]
            behaviour_type = :default
          elsif opts[:behaviour_type]
            behaviour_type = opts[:behaviour_type]
          elsif opts[:spec_path] =~ /spec(\\|\/)(#{BEHAVIOUR_CLASSES.keys.join('|')})/
            behaviour_type = $2.to_sym
          else
            behaviour_type = :default
          end
          return BEHAVIOUR_CLASSES[behaviour_type].new(*args, &block)
        end

      end
    end
  end
end
