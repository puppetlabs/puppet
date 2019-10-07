require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the ceiling function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  context 'for an integer' do
    [ 0, 1, -1].each do |x|
      it "called as ceiling(#{x}) results in the same value" do
        expect(compile_to_catalog("notify { String( ceiling(#{x}) == #{x}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'for a float' do
    {
      0.0 => 0,
      1.1 => 2,
      -1.1 => -1,
    }.each_pair do |x, expected|
      it "called as ceiling(#{x}) results in #{expected}" do
        expect(compile_to_catalog("notify { String( ceiling(#{x}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'for a string' do
    let(:logs) { [] }
    let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }

    { "0" => 0,
      "1" => 1,
      "-1" => -1,
      "0.0" => 0,
      "1.1" => 2,
      "-1.1" => -1,
      "0777" => 777,
      "-0777" => -777,
      "0xFF" => 0xFF,
    }.each_pair do |x, expected|
      it "called as ceiling('#{x}') results in #{expected} and a deprecation warning" do
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          expect(compile_to_catalog("notify { String( ceiling('#{x}') == #{expected}): }")).to have_resource("Notify[true]")
        end
        expect(warnings).to include(/auto conversion of .* is deprecated/)
      end
    end

    ['blue', '0.2.3'].each do |x|
      it "errors as the string '#{x}' cannot be converted to a float" do
        expect{ compile_to_catalog("ceiling('#{x}')") }.to raise_error(/cannot convert given value to a floating point value/)
      end
    end
  end

  [[1,2,3], {'a' => 10}].each do |x|
    it "errors for a value of class #{x.class}" do
      expect{ compile_to_catalog("ceiling(#{x})") }.to raise_error(/expects a value of type Numeric or String/)
    end
  end

end
