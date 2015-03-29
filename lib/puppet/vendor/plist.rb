#--
##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
# Patrick May <patrick@hexane.org>                           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################
#++
# = Plist
#
# This is the main file for plist.  Everything interesting happens in Plist and Plist::Emit.

require 'base64'
require 'cgi'
require 'stringio'

require 'puppet/vendor/plist/generator'
require 'puppet/vendor/plist/parser'

module Plist
  VERSION = '3.0.0'
end

# $Id: plist.rb 1781 2006-10-16 01:01:35Z luke $
