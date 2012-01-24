#
# This Rake Task is a striped down version of Buildr download task
# I took the code from http://rubyforge.org/projects/buildr
#
# I've striped down dependencies on Net::SSH and Facets to
# stay as simple as possible.
#
# Original code from Assaf Arkin in the buildr project, released under Apache
# License [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0)
#
# Licensed to Puppet Labs under one or more contributor license agreements.
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.  Puppet Labs licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may not use this file
# except in compliance with the License.  You may obtain a copy of the License
# at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

require 'rake'
require 'tempfile'

require File.join(File.dirname(__FILE__), 'contrib', 'uri_ext')

def download(args)
  args = URI.parse(args) if args.is_a?(String)

  options = {
    :progress => true,
    :verbose => Rake.application.options.trace
  }

  # Given only a download URL, download into a temporary file.
  # You can infer the file from task name.
  if URI === args
    temp = Tempfile.open(File.basename(args.to_s))
    file_create(temp.path) do |task|
      # Since temporary file exists, force a download.
      class << task ; def needed?() ; true ; end ; end
      task.sources << args
      task.enhance { args.download(temp, options) }
    end
  else
    # Download to a file task instead
    fail unless args.keys.size == 1
    uri = URI.parse(args.values.first.to_s)
    file_create(args.keys.first) do |task|
      task.sources << uri
      task.enhance { uri.download(task.name, options) }
    end
  end
end
