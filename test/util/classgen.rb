if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = ".."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

class TestPuppetUtilClassGen < Test::Unit::TestCase
    include TestPuppet

    class FakeBase
        class << self
            attr_accessor :name
        end
    end

    class GenTest
        class << self
            include Puppet::Util::ClassGen
        end
    end

    def test_genclass
        hash = {}

        name = "yayness"
        klass = nil
        assert_nothing_raised {
            klass = GenTest.genclass(name, :hash => hash, :parent => FakeBase) do
                class << self
                    attr_accessor :name
                end
            end
        }

        assert(klass.respond_to?(:name), "Class did not execute block")

        assert(hash.include?(klass.name),
            "Class did not get added to hash")
    end

    # Make sure we call a preinithook, if there is one.
    def test_inithooks
        newclass = Class.new(FakeBase) do
            class << self
                attr_accessor :preinited, :postinited
            end
            def self.preinit
                self.preinited = true
            end
            def self.postinit
                self.postinited = true
            end
        end

        klass = nil
        assert_nothing_raised {
            klass = GenTest.genclass(:yayness, :parent => newclass)
        }

        assert(klass.preinited, "prehook did not get called")
        assert(klass.postinited, "posthook did not get called")
    end
end

# $Id$
