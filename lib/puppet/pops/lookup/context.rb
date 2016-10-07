module Puppet::Pops
  module Lookup
    class Context
      include Types::PuppetObject

      def self._ptype
        @type
      end

      def self.register_ptype(loader, ir)
        tf = Types::TypeFactory
        @type = Pcore::create_object_type(loader, ir, self, 'Puppet::LookupContext', 'Any',
          {
            'environment_name' => Types::PStringType::NON_EMPTY,
            'module_name' => {
              Types::KEY_TYPE => tf.optional(Types::PStringType::NON_EMPTY),
              Types::KEY_VALUE => nil
            }
          },
          {
            'not_found' => tf.callable([0, 0], tf.undef),
            'explain' => tf.callable([0, 0, tf.callable(0,0)], tf.undef),
            'cache' => tf.callable([tf.scalar, tf.any], tf.undef),
            'cache_all' => tf.callable([tf.hash_kv(tf.scalar, tf.any)], tf.undef),
            'cached_value' => tf.callable([tf.scalar], tf.any),
            'cached_entries' => tf.variant(
              tf.callable([0, 0, tf.callable(1,1)], tf.undef),
              tf.callable([0, 0, tf.callable(2,2)], tf.undef),
              tf.callable([0, 0], tf.iterable(tf.tuple([tf.scalar, tf.any])))
            )
          }
        ).resolve(Types::TypeParser.singleton, loader)
      end

      attr_reader :environment_name
      attr_reader :module_name

      def initialize(environment_name, module_name, lookup_invocation = Invocation.current)
        @lookup_invocation = lookup_invocation
        @environment_name = environment_name
        @module_name = module_name
        @cache = {}
      end

      def cache(key, value)
        @cache[key] = value
        nil
      end

      def cache_all(hash)
        @cache.merge!(hash)
        nil
      end

      def cached_value(key)
        @cache[key]
      end

      def cached_entries(&block)
        @cache
        if block_given?
          enumerator = @cache.each_pair
          @cache.size.times do
            if block.arity == 2
              yield(*enumerator.next)
            else
              yield(enumerator.next)
            end
          end
          nil
        else
          Types::Iterable.on(@cache)
        end
      end

      def explain(&block)
        @lookup_invocation.report_text(&block) unless @lookup_invocation.nil?
        nil
      end

      def not_found
        throw :no_such_key
      end
    end
  end
end
