require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the unwrap function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'unwraps a sensitive value' do
    code = <<-CODE
      $sensitive = Sensitive.new("12345")
      notice("unwrapped value is ${sensitive.unwrap}")
    CODE
    expect(eval_and_collect_notices(code)).to eq(['unwrapped value is 12345'])
  end

  it 'unwraps a sensitive value when given a code block' do
    code = <<-CODE
      $sensitive = Sensitive.new("12345")
      $split = $sensitive.unwrap |$unwrapped| {
        notice("unwrapped value is $unwrapped")
        $unwrapped.split(/3/)
      }
      notice("split is $split")
    CODE
    expect(eval_and_collect_notices(code)).to eq(['unwrapped value is 12345', 'split is [12, 45]'])
  end
end
