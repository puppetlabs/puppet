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

  shared_examples_for "virtual resource collection" do
    it "matches everything when no query given" do
      expect_the_message_to_be(["the other message", "the message"], <<-MANIFEST)
        @notify { "testing": message => "the message" }
        @notify { "other": message => "the other message" }

        Notify <| |>
      MANIFEST
    end

    it "matches on tags" do
      expect_the_message_to_be(["wanted"], <<-MANIFEST)
        @notify { "testing": tag => ["one"], message => "wanted" }
        @notify { "other": tag => ["two"], message => "unwanted" }

        Notify <| tag == one |>
      MANIFEST
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

    it "matches against elements of an array valued parameter" do
      expect_the_message_to_be([["the", "message"]], <<-MANIFEST)
        @notify { "testing": message => ["the", "message"] }
        @notify { "other testing": message => ["not", "here"] }

        Notify <| message == "message" |>
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

    it "does not exclude resources with unequal arrays" do
      expect_the_message_to_be(["message", ["not this message", "or this one"]], <<-MANIFEST)
        @notify { "testing": message => "message" }
        @notify { "the wrong one": message => ["not this message", "or this one"] }

        Notify <| message != "not this message" |>
      MANIFEST
    end

    it "does not exclude tags with inequalities" do
      expect_the_message_to_be(["wanted message", "the way it works"], <<-MANIFEST)
        @notify { "testing": tag => ["wanted"], message => "wanted message" }
        @notify { "other": tag => ["why"], message => "the way it works" }

        Notify <| tag != "why" |>
      MANIFEST
    end

    context "overrides" do
      it "modifies an existing array" do
        expect_the_message_to_be([["original message", "extra message"]], <<-MANIFEST)
          @notify { "testing": message => ["original message"] }

          Notify <| |> {
            message +> "extra message"
          }
        MANIFEST
      end

      it "converts a scalar to an array" do
        expect_the_message_to_be([["original message", "extra message"]], <<-MANIFEST)
          @notify { "testing": message => "original message" }

          Notify <| |> {
            message +> "extra message"
          }
        MANIFEST
      end

      it "collects with override when inside a class (#10963)" do
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

      it "collects with override when inside a define (#10963)" do
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

  describe "in the current parser" do
    before :each do
      Puppet[:parser] = 'current'
    end

    it_behaves_like "virtual resource collection"
  end

  describe "in the future parser" do
    before :each do
      Puppet[:parser] = 'future'
    end

    it_behaves_like "virtual resource collection"
  end
end
