require File.dirname(__FILE__) + '/../spec_helper'

class Hiera
    module Puppet_logger
        describe "#warn" do
            it "should log using Puppet.notice" do
                Puppet.expects(:notice).with("hiera(): foo")
                Puppet_logger.warn("foo")
            end
        end

        describe "#debug" do
            it "should log using Puppet.debug" do
                Puppet.expects(:debug).with("hiera(): foo")
                Puppet_logger.debug("foo")
            end
        end
    end
end

