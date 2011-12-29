#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/retryaction'

describe Puppet::Util::RetryAction do
  let (:exceptions) {{ Puppet::Error => 'Puppet Error Exception' }}
  
  it 'should retry on any exception if no acceptable exceptions given' do
    expect do
      Puppet::Util::RetryAction.retry_action( :timeout => 5 ) do
        raise ArgumentError, 'Fake Failure'
      end
    end.to raise_exception(Puppet::Util::RetryAction::RetryException::Timeout)
  end

  it 'should retry on acceptable exceptions' do
    expect do
      Puppet::Util::RetryAction.retry_action( :timeout => 5, :retry_exceptions => exceptions) do
        raise Puppet::Error, 'Fake Failure'
      end
    end.to raise_error(Puppet::Util::RetryAction::RetryException::Timeout)
  end

  it 'should not retry on unacceptable exceptions' do
    expect do
      Puppet::Util::RetryAction.retry_action( :timeout => 5, :retry_exceptions => exceptions) do
        raise ArgumentError
      end
    end.to raise_exception(ArgumentError)
  end
end
