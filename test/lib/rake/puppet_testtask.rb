#!/usr/bin/env ruby

module Rake
    class PuppetTestTask < Rake::TestTask
        def rake_loader
            file = find_file('rake/puppet_test_loader') or
                fail "unable to find rake test loader"
            puts file
            return file
        end
    end
end

# $Id$
