#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'

require 'puppet/parser/collector'

describe Puppet::Parser::Collector do
  include PuppetSpec::Compiler

  def expect_the_message_to_be(expected_messages, code, node = Puppet::Node.new('the node'))
    catalog = compile_to_catalog(code, node)
    messages = catalog.resources.find_all { |resource| resource.type == 'Notify' }.
                                 collect { |notify| notify[:message] }
    messages.should include(*expected_messages)
  end

  it "matches on title" do
    expect_the_message_to_be(["the message"], <<-MANIFEST)
      @notify { "testing": message => "the message" }

      Notify <| title == "testing" |>
    MANIFEST
  end

  it "matches on other parameters" do
    expect_the_message_to_be(["the message"], <<-MANIFEST)
      @notify { "testing": message => "the message" }
      @notify { "other testing": message => "the wrong message" }

      Notify <| message == "the message" |>
    MANIFEST
  end

  it "allows criteria to be combined with 'and'" do
    expect_the_message_to_be(["the message"], <<-MANIFEST)
      @notify { "testing": message => "the message" }
      @notify { "other": message => "the message" }

      Notify <| title == "testing" and message == "the message" |>
    MANIFEST
  end

  it "allows criteria to be combined with 'or'" do
    expect_the_message_to_be(["the message", "other message"], <<-MANIFEST)
      @notify { "testing": message => "the message" }
      @notify { "other": message => "other message" }
      @notify { "yet another": message => "different message" }

      Notify <| title == "testing" or message == "other message" |>
    MANIFEST
  end

  it "allows criteria to be combined with 'or'" do
    expect_the_message_to_be(["the message", "other message"], <<-MANIFEST)
      @notify { "testing": message => "the message" }
      @notify { "other": message => "other message" }
      @notify { "yet another": message => "different message" }

      Notify <| title == "testing" or message == "other message" |>
    MANIFEST
  end

  it "allows criteria to be grouped with parens" do
    expect_the_message_to_be(["the message", "different message"], <<-MANIFEST)
      @notify { "testing":     message => "different message", withpath => true }
      @notify { "other":       message => "the message" }
      @notify { "yet another": message => "the message",       withpath => true }

      Notify <| (title == "testing" or message == "the message") and withpath == true |>
    MANIFEST
  end

  it "does not do anything if nothing matches" do
    expect_the_message_to_be([], <<-MANIFEST)
      @notify { "testing": message => "different message" }

      Notify <| title == "does not exist" |>
    MANIFEST
  end

  it "excludes items with inequalities" do
    expect_the_message_to_be(["good message"], <<-MANIFEST)
      @notify { "testing": message => "good message" }
      @notify { "the wrong one": message => "bad message" }

      Notify <| title != "the wrong one" |>
    MANIFEST
  end

  context "issue #10963" do
    it "collects with override when inside a class" do
      expect_the_message_to_be(["overridden message"], <<-MANIFEST)
        @notify { "testing": message => "original message" }

        include collector_test
        class collector_test {
          Notify <| |> {
            message => "overridden message"
          }
        }
      MANIFEST
    end

    it "collects with override when inside a define" do
      expect_the_message_to_be(["overridden message"], <<-MANIFEST)
        @notify { "testing": message => "original message" }

        collector_test { testing: }
        define collector_test() {
          Notify <| |> {
            message => "overridden message"
          }
        }
      MANIFEST
    end
  end
end
