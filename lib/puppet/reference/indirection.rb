require 'puppet/indirector/indirection'
require 'puppet/util/checksums'
require 'puppet/file_serving/content'
require 'puppet/file_serving/metadata'

reference = Puppet::Util::Reference.newreference :indirection, :doc => "Indirection types and their terminus classes" do
  text = ""
  Puppet::Indirector::Indirection.instances.sort { |a,b| a.to_s <=> b.to_s }.each do |indirection|
    ind = Puppet::Indirector::Indirection.instance(indirection)
    name = indirection.to_s.capitalize
    text << "## " + indirection.to_s + "\n\n"

    text << ind.doc + "\n\n"

    Puppet::Indirector::Terminus.terminus_classes(ind.name).sort { |a,b| a.to_s <=> b.to_s }.each do |terminus|
      terminus_name = terminus.to_s
      term_class = Puppet::Indirector::Terminus.terminus_class(ind.name, terminus)
      terminus_doc = Puppet::Util::Docs.scrub(term_class.doc)
      text << markdown_definitionlist(terminus_name, terminus_doc)
    end
  end

  text
end

reference.header = "This is the list of all indirections, their associated terminus classes, and how you select between them.

In general, the appropriate terminus class is selected by the application for you (e.g., `puppet agent` would always use the `rest`
terminus for most of its indirected classes), but some classes are tunable via normal settings.  These will have `terminus setting` documentation listed with them.


"
