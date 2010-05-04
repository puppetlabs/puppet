#!/usr/bin/ruby
#
# = Synopsis
#
# Use YAML files to provide external node support.
#
# = Usage
#
#   yaml-nodes <host>
#
# = Description
#
# This is a simple example external node script.  It allows you to maintain your
# node information in yaml files, and it will find a given node's file and produce
# it on stdout.  It has simple inheritance, in that a node can specify a parent
# node, and the node will inherit that parent's classes and parameters.
#
# = Options
#
# help::
#   Print this help message
#
# yamldir::
#   Specify where the yaml is found.  Defaults to 'yaml' in the current directory.
#
# = Author
#
# Luke Kanies
#
# = Copyright
#
# Copyright (c) 2009 Puppet Labs, Inc.
# Licensed under the GPL2

require 'yaml'
require 'optparse'

BASEDIR = Dir.chdir(File.dirname(__FILE__) + "/..") { Dir.getwd }

options = {:yamldir => File.join(BASEDIR, "yaml")}
OptionParser.new do |opts|
    opts.banner = "Usage: yaml-nodes [options] <host>"

    opts.on("-y dir", "--yamldir dir", "Specify the directory with the YAML files") do |arg|
        raise "YAML directory #{arg} does not exist or is not a directory" unless FileTest.directory?(arg)
        options[:yamldir] = arg
    end

    opts.on("-h", "--help", "Print this help") do
        puts opts.help
        exit(0)
    end
end.parse!

# Read in a pure yaml representation of our node.
def read_node(node)
    nodefile = File.join(YAMLDIR, "#{node}.yaml")
    if FileTest.exist?(nodefile)
        return YAML.load_file(nodefile)
    else
        raise "Could not find information for %s" % node
    end
end

node = ARGV[0]

info = read_node(node)

# Iterate over any provided parents, merging in there information.
parents_seen = []
while parent = info["parent"]
    raise "Found inheritance loop with parent %s" % parent if parents_seen.include?(parent)

    parents_seen << parent

    info.delete("parent")

    parent_info = read_node(parent)

    # Include any parent classes in our list.
    if pclasses = parent_info["classes"]
        info["classes"] += pclasses
        info["classes"].uniq!
    end

    # And inherit parameters from our parent, while preferring our own values.
    if pparams = parent_info["parameters"]
        # When using Hash#merge, the hash being merged in wins, and we
        # want the subnode parameters to be the parent node parameters.
        info["parameters"] = pparams.merge(info["parameters"])
    end

    # Copy over any parent node name.
    if pparent = parent_info["parent"]
        info["parent"] = pparent
    end
end

puts YAML.dump(info)
