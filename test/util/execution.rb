if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = ".."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

class TestPuppetUtilExecution < Test::Unit::TestCase
    include TestPuppet

    def test_withenv
        ENV["testing"] = "yay"

        assert_nothing_raised do
            Puppet::Util::Execution.withenv :testing => "foo" do
                $ran = ENV["testing"]
            end
        end

        assert_equal("yay", ENV["testing"])
        assert_equal("foo", $ran)

        ENV["rah"] = "yay"
        assert_raise(ArgumentError) do
            Puppet::Util::Execution.withenv :testing => "foo" do
                raise ArgumentError, "yay"
            end
        end

        assert_equal("yay", ENV["rah"])
    end
end

# $Id$
