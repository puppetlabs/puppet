#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/monkey_patches'

describe RDoc do
    it "should return the call stack if a script is called directly" do
        stack = [
            "/usr/lib/ruby/1.8/rdoc/usage.rb:99:in `usage_no_exit'",
            "/usr/lib/ruby/1.8/rdoc/usage.rb:93:in `usage'",
            "./puppet/application.rb:295:in `help'",
            "./puppet/application.rb:207:in `handle_help'",
            "./puppet/application.rb:141:in `send'",
            "./puppet/application.rb:141:in `option'", 
            "/usr/lib/ruby/1.8/optparse.rb:1267:in `call'", 
            "/usr/lib/ruby/1.8/optparse.rb:1267:in `parse_in_order'", 
            "/usr/lib/ruby/1.8/optparse.rb:1254:in `catch'", 
            "/usr/lib/ruby/1.8/optparse.rb:1254:in `parse_in_order'", 
            "/usr/lib/ruby/1.8/optparse.rb:1248:in `order!'", 
            "/usr/lib/ruby/1.8/optparse.rb:1339:in `permute!'", 
            "/usr/lib/ruby/1.8/optparse.rb:1360:in `parse!'", 
            "./puppet/application.rb:262:in `parse_options'", 
            "./puppet/application.rb:214:in `run'", 
            "./puppet/application.rb:306:in `exit_on_fail'", 
            "./puppet/application.rb:214:in `run'", 
            "../bin/puppet:71"
        ]

        old_dollar_zero = $0
        $0 = "../bin/puppet"

        # Mocha explodes if you try to mock :caller directly
        Kernel.expects( :mock_caller ).returns( stack )
        Kernel.instance_eval { alias orig_caller caller      }
        Kernel.instance_eval { alias caller      mock_caller }

        RDoc.caller.must == stack

        $0 = old_dollar_zero
        Kernel.instance_eval { alias caller      orig_caller }
    end

    it "should return a truncated call stack if a script is called from a rubygems stub" do
        gem_stack = [
            "/usr/lib/ruby/1.8/rdoc/usage.rb:99:in `usage_no_exit'", 
            "/usr/lib/ruby/1.8/rdoc/usage.rb:93:in `usage'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:295:in `help'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:207:in `handle_help'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:141:in `send'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:141:in `option'", 
            "/usr/lib/ruby/1.8/optparse.rb:1267:in `call'", 
            "/usr/lib/ruby/1.8/optparse.rb:1267:in `parse_in_order'", 
            "/usr/lib/ruby/1.8/optparse.rb:1254:in `catch'", 
            "/usr/lib/ruby/1.8/optparse.rb:1254:in `parse_in_order'", 
            "/usr/lib/ruby/1.8/optparse.rb:1248:in `order!'", 
            "/usr/lib/ruby/1.8/optparse.rb:1339:in `permute!'", 
            "/usr/lib/ruby/1.8/optparse.rb:1360:in `parse!'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:262:in `parse_options'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:214:in `run'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:306:in `exit_on_fail'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:214:in `run'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/bin/puppet:71", 
            "/usr/bin/puppet:19:in `load'", 
            "/usr/bin/puppet:19"
        ]

        real_stack = [
            "/usr/lib/ruby/1.8/rdoc/usage.rb:99:in `usage_no_exit'", 
            "/usr/lib/ruby/1.8/rdoc/usage.rb:93:in `usage'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:295:in `help'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:207:in `handle_help'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:141:in `send'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:141:in `option'", 
            "/usr/lib/ruby/1.8/optparse.rb:1267:in `call'", 
            "/usr/lib/ruby/1.8/optparse.rb:1267:in `parse_in_order'", 
            "/usr/lib/ruby/1.8/optparse.rb:1254:in `catch'", 
            "/usr/lib/ruby/1.8/optparse.rb:1254:in `parse_in_order'", 
            "/usr/lib/ruby/1.8/optparse.rb:1248:in `order!'", 
            "/usr/lib/ruby/1.8/optparse.rb:1339:in `permute!'", 
            "/usr/lib/ruby/1.8/optparse.rb:1360:in `parse!'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:262:in `parse_options'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:214:in `run'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:306:in `exit_on_fail'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/lib/puppet/application.rb:214:in `run'", 
            "/usr/lib/ruby/gems/1.8/gems/puppet-0.25.1/bin/puppet:71", 
        ]

        old_dollar_zero = $0
        $0 = '/usr/bin/puppet'

        # Mocha explodes if you try to mock :caller directly
        Kernel.expects( :mock_caller ).returns( gem_stack )
        Kernel.instance_eval { alias orig_caller caller      }
        Kernel.instance_eval { alias caller      mock_caller }

        RDoc.caller.must == real_stack

        $0 = old_dollar_zero
        Kernel.instance_eval { alias caller      orig_caller }
    end
end

