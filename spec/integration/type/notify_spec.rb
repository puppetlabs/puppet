require 'spec_helper'
require 'puppet_spec/compiler'

describe Puppet::Type.type(:notify) do
  include PuppetSpec::Compiler

  it "logs the title at notice level" do
    apply_compiled_manifest(<<-MANIFEST)
      notify { 'hi': }
    MANIFEST

    expect(@logs).to include(an_object_having_attributes(level: :notice, message: 'hi'))
  end

  it "logs the message property" do
    apply_compiled_manifest(<<-MANIFEST)
      notify { 'title':
        message => 'hello'
      }
    MANIFEST

    expect(@logs).to include(an_object_having_attributes(level: :notice, message: "defined 'message' as 'hello'"))
  end

  it "redacts sensitive message properties" do
    apply_compiled_manifest(<<-MANIFEST)
      $message = Sensitive('secret')
      notify { 'notify1':
        message => $message
      }
    MANIFEST

    expect(@logs).to include(an_object_having_attributes(level: :notice, message: 'changed [redacted] to [redacted]'))
  end

  it "redacts sensitive interpolated message properties" do
    apply_compiled_manifest(<<-MANIFEST)
      $message = Sensitive('secret')
      notify { 'notify2':
        message => "${message}"
      }
    MANIFEST

    expect(@logs).to include(an_object_having_attributes(level: :notice, message: "defined 'message' as 'Sensitive [value redacted]'"))
  end
end
