require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'The Task Type' do
  include PuppetSpec::Compiler

  it 'can present itself as json' do
    code = <<-PUPPET.unindent
    
      type Service::Action = Enum[
        # Start the service
        'start',
        # Stop the service,
        'stop',
        # Restart the service
        'restart',
        # Ensure that the service is enabled
        'enable',
        # Disable the service
        'disable',
        # Report the current status of the service
        'Status'
      ]

      # @summary Manage and inspect the state of services
      # @parameter action The operation (start, stop, restart, enable, disable, status) to perform on the service
      # @parameter service The name of the service to install
      # @parameter provider The provider to use to manage or inspect the service, defaults to the system service manager
      type Service::Init = Task {
        constants => {
          supports_noop => true,
          input_format => 'stdin:json'
        },
        attributes => {
          action => Service::Action,
          service => String[1],
          provider => {
            type => String[1],
            value => 'system'
          }
        }
      }
      notice(Service::Init('restart', 'httpd').task_json())
    PUPPET
    expect(eval_and_collect_notices(code)[0]).to eql('{"action":"restart","service":"httpd"}')
  end
end
end
end

