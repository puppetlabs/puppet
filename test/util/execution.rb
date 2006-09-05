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
                $ran = true
            end
        end

        assert_equal("yay", ENV["testing"])
        assert_equal(true, $ran)

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
