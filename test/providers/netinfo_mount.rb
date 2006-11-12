#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2006-11-12.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
# 
# if Puppet::Type.type(:mount).provider(:netinfo).suitable?
# class TestNetinfoMountProvider < Test::Unit::TestCase
# 	include PuppetTest
# 	
# 	def setup
# 	    super
# 	    @mount = Puppet::Type.type(:mount)
#     end
#     
#     if Process.uid == 0 and Facter.value(:hostname) == "midden"
#     def test_mount_nfs
#         culain = nil
#         assert_nothing_raised do
#             culain = @mount.create :name => "/mnt", :device => "culain:/home/luke", :options => "-o -P", :ensure => :present,
#                 :fstype => "nfs"
#         end
#         
#         assert(culain, "Did not create fs")
#         
#         assert_apply(culain)
# 
#         assert_nothing_raised do
#             culain.provider.mount
#         end
#         
#         assert(culain.provider.mounted?, "fs is not considered mounted")
#         assert_nothing_raised() { culain.provider.unmount }
#         
#         culain[:ensure] = :absent
#         
#         assert_apply(culain)
#     end
#     end
#     
#     def test_simple
#         root = nil
#         assert_nothing_raised do
#             root = @mount.create :name => "/", :check => @mount.validstates
#         end
#         
#         assert_nothing_raised do
#             root.retrieve
#         end
#         
#         prov = root.provider
#         
#         assert_nothing_raised do
#             assert(prov.device, "Did not value for device")
#             assert(prov.device != :absent, "Netinfo thinks the root device is missing")
#         end
#     end
# 	
# 	def test_list
# 	    list = nil
# 	    assert_nothing_raised do
# 	        list = @mount.list
#         end
#         assert(list.length > 0)
#         list.each do |obj|
#             assert_instance_of(@mount, obj)
#             assert(obj[:name], "objects do not have names")
#             p obj
#             assert(obj.is(:device), "Did not get value for device in %s" % obj[:name])
#         end
#         
#         assert(list.detect { |m| m[:name] == "/"}, "Could not find root fs")
#     end
# end
# end

# $Id$