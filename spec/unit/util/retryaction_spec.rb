#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/retryaction'

describe Puppet::Util::RetryAction do
  let (:exceptions) {{ Puppet::Error => 'Puppet Error Exception' }}

  it 'should retry on any exception if no acceptable exceptions given' do
    Puppet::Util::RetryAction.expects(:sleep).with( (((2 ** 1) -1) * 0.1) )
    Puppet::Util::RetryAction.expects(:sleep).with( (((2 ** 2) -1) * 0.1) )

    expect do
      Puppet::Util::RetryAction.retry_action( :retries => 2 ) do
        raise ArgumentError, 'Fake Failure'
      end
    end.to raise_exception(Puppet::Util::RetryAction::RetryException::RetriesExceeded)
  end

  it 'should retry on acceptable exceptions' do
    Puppet::Util::RetryAction.expects(:sleep).with( (((2 ** 1) -1) * 0.1) )
    Puppet::Util::RetryAction.expects(:sleep).with( (((2 ** 2) -1) * 0.1) )

    expect do
      Puppet::Util::RetryAction.retry_action( :retries => 2, :retry_exceptions => exceptions) do
        raise Puppet::Error, 'Fake Failure'
      end
    end.to raise_exception(Puppet::Util::RetryAction::RetryException::RetriesExceeded)
  end

  it 'should not retry on unacceptable exceptions' do
    Puppet::Util::RetryAction.expects(:sleep).never

    expect do
      Puppet::Util::RetryAction.retry_action( :retries => 2, :retry_exceptions => exceptions) do
        raise ArgumentError
      end
    end.to raise_exception(ArgumentError)
  end

  it 'should succeed if nothing is raised' do
    Puppet::Util::RetryAction.expects(:sleep).never

    Puppet::Util::RetryAction.retry_action( :retries => 2) do
      true
    end
  end

  it 'should succeed if an expected exception is raised retried and succeeds' do
    should_retry = nil
    Puppet::Util::RetryAction.expects(:sleep).once

    Puppet::Util::RetryAction.retry_action( :retries => 2, :retry_exceptions => exceptions) do
      if should_retry
        true
      else
        should_retry = true
        raise Puppet::Error, 'Fake error'
      end
    end
  end
end
