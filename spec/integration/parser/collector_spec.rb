#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/parser/collector'

describe Puppet::Parser::Collector do
  before do
    @scope = Puppet::Parser::Scope.new(:compiler => Puppet::Parser::Compiler.new(Puppet::Node.new("mynode")))

    @resource = Puppet::Parser::Resource.new("file", "/tmp/testing", :scope => @scope, :source => "fakesource")
    {:owner => "root", :group => "bin", :mode => "644"}.each do |param, value|
      @resource[param] = value
    end
  end

  def query(text)
    code = "File <| #{text} |>"
    parser = Puppet::Parser::Parser.new(@scope.compiler)
    return parser.parse(code).code[0].query
  end

  {true => [%{title == "/tmp/testing"}, %{(title == "/tmp/testing")}, %{group == bin},
    %{title == "/tmp/testing" and group == bin}, %{title == bin or group == bin},
    %{title == "/tmp/testing" or title == bin}, %{title == "/tmp/testing"},
    %{(title == "/tmp/testing" or title == bin) and group == bin}],
  false => [%{title == bin}, %{title == bin or (title == bin and group == bin)},
    %{title != "/tmp/testing"}, %{title != "/tmp/testing" and group != bin}]
  }.each do |result, ary|
    ary.each do |string|
      it "should return '#{result}' when collecting resources with '#{string}'" do
        str, code = query(string).evaluate @scope
        code.should be_instance_of(Proc)
        code.call(@resource).should == result
      end
    end
  end
end
