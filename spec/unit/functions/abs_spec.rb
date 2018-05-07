require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the abs function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  context 'for an integer' do
    { 0 => 0,
      1 => 1,
      -1 => 1 }.each_pair do |x, expected|
      it "called as abs(#{x}) results in #{expected}" do
        expect(compile_to_catalog("notify { String( abs(#{x}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'for an float' do
    { 0.0 => 0.0,
      1.0 => 1.0,
      -1.1 => 1.1 }.each_pair do |x, expected|
      it "called as abs(#{x}) results in #{expected}" do
        expect(compile_to_catalog("notify { String( abs(#{x}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'for a string' do
    let(:logs) { [] }
    let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }

    { "0" => 0,
      "1" => 1,
      "-1" => 1,
      "0.0" => 0.0,
      "1.1" => 1.1,
      "-1.1" => 1.1,
      "0777" => 777,
      "-0777" => 777,
    }.each_pair do |x, expected|
      it "called as abs('#{x}') results in #{expected} and deprecation warning" do
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          expect(compile_to_catalog("notify { String( abs('#{x}') == #{expected}): }")).to have_resource("Notify[true]")
        end
        expect(warnings).to include(/auto conversion of .* is deprecated/)
      end
    end

    ['blue', '0xFF'].each do |x|
      it "errors when the string is not a decimal integer '#{x}' (indirectly deprecated)" do
        expect{ compile_to_catalog("abs('#{x}')") }.to raise_error(/was given non decimal string/)
      end
    end

    ['0.2.3', '1E+10'].each do |x|
      it "errors when the string is not a supported decimal float '#{x}' (indirectly deprecated)" do
        expect{ compile_to_catalog("abs('#{x}')") }.to raise_error(/was given non decimal string/)
      end
    end
  end

  [[1,2,3], {'a' => 10}].each do |x|
    it "errors for a value of class #{x.class}" do
      expect{ compile_to_catalog("abs(#{x})") }.to raise_error(/expects a value of type Numeric or String/)
    end
  end

end
