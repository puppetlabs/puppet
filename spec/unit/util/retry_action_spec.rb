#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/retry_action'

describe Puppet::Util::RetryAction do
  let (:exceptions) { [ Puppet::Error, NameError ] }

  it "doesn't retry SystemExit" do
    expect do
      Puppet::Util::RetryAction.retry_action( :retries => 0 ) do
        raise SystemExit
      end
    end.to exit_with(0)
  end

  it "doesn't retry NoMemoryError" do
    expect do
      Puppet::Util::RetryAction.retry_action( :retries => 0 ) do
        raise NoMemoryError, "OOM"
      end
    end.to raise_error(NoMemoryError, /OOM/)
  end

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

  it "doesn't mutate caller's arguments" do
    options = { :retries => 1 }.freeze

    Puppet::Util::RetryAction.retry_action(options) do
    end
  end
end
