require 'spec_helper'

RSpec.shared_context('provider specificity') do
  around do |example|
    old_defaults = described_class.instance_variable_get(:@defaults)
    old_notdefaults = described_class.instance_variable_get(:@notdefaults)
    begin
      described_class.instance_variable_set(:@defaults, [])
      described_class.instance_variable_set(:@notdefaults, [])
      example.run
    ensure
      described_class.instance_variable_set(:@defaults, old_defaults)
      described_class.instance_variable_set(:@notdefaults, old_notdefaults)
    end
  end
end
