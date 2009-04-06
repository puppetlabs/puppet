require 'puppet/util'

module Puppet::Util::CacheAccumulator
    def self.included(klass)
        klass.extend ClassMethods
    end

    class Base
        attr_reader :klass, :attribute

        def initialize(klass, attribute)
            @klass = klass
            @attribute = attribute
            @find_or_create = "find_or_create_by_#{@attribute.to_s}".intern
        end

        def store
            @store || reset
        end

        def reset
            @store = {}
        end

        def find(*keys)
            result = nil
            if keys.length == 1
                result = store[keys[0]] ||= @klass.send(@find_or_create, *keys)
            else
                found, missing = keys.partition {|k| store.include? k}
                result = found.length
                result += do_multi_find(missing) if missing.length > 0
            end
            result
        end

        def do_multi_find(keys)
            result = 0
            @klass.find(:all, :conditions => {@attribute => keys}).each do |obj|
                store[obj.send(@attribute)] = obj
                result += 1
            end
            result
        end
    end

    module ClassMethods
        def accumulates(*attributes)
            attributes.each {|attrib| install_accumulator(attrib)}
        end

        def accumulators
            @accumulators ||= {}
        end

        def install_accumulator(attribute)
            self.accumulators[attribute] = Base.new(self, attribute)
            module_eval %{
                def self.accumulate_by_#{attribute.to_s}(*keys)
                    accumulators[:#{attribute.to_s}].find(*keys)
                end
            }
        end
    end
end
