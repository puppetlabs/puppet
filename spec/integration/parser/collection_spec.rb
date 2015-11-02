#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'

describe 'collectors' do
  include PuppetSpec::Compiler

  def expect_the_message_to_be(expected_messages, code, node = Puppet::Node.new('the node'))
    catalog = compile_to_catalog(code, node)
    messages = catalog.resources.find_all { |resource| resource.type == 'Notify' }.
                                 collect { |notify| notify[:message] }
    expect(messages).to include(*expected_messages)
  end

  context "virtual resource collection" do
    it "matches everything when no query given" do
      expect_the_message_to_be(["the other message", "the message"], <<-MANIFEST)
        @notify { "testing": message => "the message" }
        @notify { "other": message => "the other message" }

        Notify <| |>
      MANIFEST
    end

    it "matches regular resources " do
      expect_the_message_to_be(["changed", "changed"], <<-MANIFEST)
        notify { "testing": message => "the message" }
        notify { "other": message => "the other message" }

        Notify <| |> { message => "changed" }
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

    it "matches with bare word" do
      expect_the_message_to_be(["wanted"], <<-MANIFEST)
        @notify { "testing": tag => ["one"], message => "wanted" }
        Notify <| tag == one |>
      MANIFEST
    end

    it "matches with single quoted string" do
      expect_the_message_to_be(["wanted"], <<-MANIFEST)
        @notify { "testing": tag => ["one"], message => "wanted" }
        Notify <| tag == 'one' |>
      MANIFEST
    end

    it "matches with double quoted string" do
      expect_the_message_to_be(["wanted"], <<-MANIFEST)
        @notify { "testing": tag => ["one"], message => "wanted" }
        Notify <| tag == "one" |>
      MANIFEST
    end

    it "matches with double quoted string with interpolated expression" do
      expect_the_message_to_be(["wanted"], <<-MANIFEST)
        @notify { "testing": tag => ["one"], message => "wanted" }
        $x = 'one'
        Notify <| tag == "$x" |>
      MANIFEST
    end

    it "matches with resource references" do
      expect_the_message_to_be(["wanted"], <<-MANIFEST)
        @notify { "foobar": }
        @notify { "testing": require => Notify["foobar"], message => "wanted" }
        Notify <| require == Notify["foobar"] |>
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

    it "does not collect classes" do
      node = Puppet::Node.new('the node')
      expect do
        catalog = compile_to_catalog(<<-MANIFEST, node)
          class theclass {
            @notify { "testing": message => "good message" }
          }
          Class <|  |>
        MANIFEST
      end.to raise_error(/Classes cannot be collected/)
    end

    it "does not collect resources that don't exist" do
      node = Puppet::Node.new('the node')
      expect do
        catalog = compile_to_catalog(<<-MANIFEST, node)
          class theclass {
            @notify { "testing": message => "good message" }
          }
          SomeResource <|  |>
        MANIFEST
      end.to raise_error(/Resource type someresource doesn't exist/)
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

      # Catches regression in implemented behavior, this is not to be taken as this is the wanted behavior
      # but it has been this way for a long time.
      it "collects and overrides user defined resources immediately (before queue is evaluated)" do
        expect_the_message_to_be(["overridden"], <<-MANIFEST)
          define foo($message) {
            notify { "testing": message => $message }
          }
          foo { test: message => 'given' }
          Foo <|  |> { message => 'overridden' }
        MANIFEST
      end

      # Catches regression in implemented behavior, this is not to be taken as this is the wanted behavior
      # but it has been this way for a long time.
      it "collects and overrides user defined resources immediately (virtual resources not queued)" do
        expect_the_message_to_be(["overridden"], <<-MANIFEST)
          define foo($message) {
            @notify { "testing": message => $message }
          }
          foo { test: message => 'given' }
          Notify <| |> # must be collected or the assertion does not find it
          Foo <|  |> { message => 'overridden' }
        MANIFEST
      end

      # Catches regression in implemented behavior, this is not to be taken as this is the wanted behavior
      # but it has been this way for a long time.
      # Note difference from none +> case where the override takes effect
      it "collects and overrides user defined resources with +>" do
        expect_the_message_to_be([["given", "overridden"]], <<-MANIFEST)
          define foo($message) {
            notify { "$name": message => $message }
          }
          foo { test: message => ['given'] }
          Notify <|  |> { message +> ['overridden'] }
        MANIFEST
      end

      it "collects and overrides virtual resources multiple times using multiple collects" do
        expect_the_message_to_be(["overridden2"], <<-MANIFEST)
          @notify { "testing": message => "original" }
          Notify <|  |> { message => 'overridden1' }
          Notify <|  |> { message => 'overridden2' }
        MANIFEST
      end

      it "collects and overrides non virtual resources multiple times using multiple collects" do
        expect_the_message_to_be(["overridden2"], <<-MANIFEST)
          notify { "testing": message => "original" }
          Notify <|  |> { message => 'overridden1' }
          Notify <|  |> { message => 'overridden2' }
        MANIFEST
      end

    end
  end

end
