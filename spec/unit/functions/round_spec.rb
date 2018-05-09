require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the round function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  context 'for an integer' do
    [ 0, 1, -1].each do |x|
      it "called as round(#{x}) results in the same value" do
        expect(compile_to_catalog("notify { String( round(#{x}) == #{x}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'for a float' do
    {
      0.0 => 0,
      1.1 => 1,
      -1.1 => -1,
      2.9 => 3,
      2.1 => 2,
      2.49 => 2,
      2.50 => 3,
      -2.9 => -3,
    }.each_pair do |x, expected|
      it "called as round(#{x}) results in #{expected}" do
        expect(compile_to_catalog("notify { String( round(#{x}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  [[1,2,3], {'a' => 10}, '"42"'].each do |x|
    it "errors for a value of class #{x.class}" do
      expect{ compile_to_catalog("round(#{x})") }.to raise_error(/expects a Numeric value/)
    end
  end

end
