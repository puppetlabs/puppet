# Static Compiler

The static compiler was added to Puppet in the 2.7.0 release.
[1](http://links.puppetlabs.com/static-compiler-announce)

The static compiler is intended to provide a configuration catalog that
requires a minimal amount of network communication in order to apply the
catalog to the system.  As implemented in Puppet 2.7.x and Puppet 3.0.x this
intention takes the form of replacing all of the source parameters of File
resources with a content parameter containing an address in the form of a
checksum.  The expected behavior is that the process applying the catalog to
the node will retrieve the file content from the FileBucket instead of the
FileServer.

The high level approach can be described as follows.  The `StaticCompiler` is a
terminus that inserts itself between the "normal" compiler terminus and the
request.  The static compiler takes the resource catalog produced by the
compiler and filters all File resources.  Any file resource that contains a
source parameter with a value starting with 'puppet://' is filtered in the
following way in a "standard" single master / networked agents deployment
scenario:

 1. The content, owner, group, and mode values are retrieved from th
     FileServer by the master.
 2. The file content is stored in the file bucket on the master.
 3. The source parameter value is stripped from the File resource.
 4. The content parameter value is set in the File resource using the form
    '{XXX}1234567890' which can be thought of as a content address indexed by
    checksum.
 5. The owner, group and mode values are set in the File resource if they are
    not already set.
 6. The filtered catalog is returned in the response.

In addition to the catalog terminus, the process requesting the catalog needs
to obtain the file content.  The default behavior of `puppet agent` is to
obtain file contents from the local client bucket.  The method we expect users
to employ to reconfigure the agent to use the server bucket is to declare the
`Filebucket[puppet]` resource with the address of the master. For example:

    node default {
      filebucket { puppet:
        server => $server,
        path   => false,
      }
      class { filetest: }
    }

This special filebucket resource named "puppet" will cause the agent to fetch
file contents specified by checksum from the remote filebucket instead of the
default clientbucket.

## Trying out the Static Compiler

Create a module that recursively downloads something.  The jeffmccune-filetest
module will recursively copy the rubygems source tree.

    $ bundle exec puppet module install jeffmccune-filetest

Start the master with the StaticCompiler turned on:

    $ bundle exec puppet master \
        --catalog_terminus=static_compiler \
        --verbose \
        --no-daemonize

Add the special Filebucket[puppet] resource:

    # site.pp
    node default {
      filebucket { puppet: server => $server, path => false }
      class { filetest: }
    }

Get the static catalog:

    $ bundle exec puppet agent --test

You should expect all file metadata to be contained in the catalog, including a
checksum representing the content.  When managing an out of sync file resource,
the real contents should be fetched from the server instead of the
clientbucket.


