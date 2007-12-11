require 'puppet/indirector/indirection'
require 'puppet/checksum'
require 'puppet/file_serving/content'
require 'puppet/file_serving/metadata'

reference = Puppet::Util::Reference.newreference :indirection, :doc => "Indirection types and their terminus classes" do
    text = ""
    Puppet::Indirector::Indirection.instances.sort { |a,b| a.to_s <=> b.to_s }.each do |indirection|
        ind = Puppet::Indirector::Indirection.instance(indirection)
        name = indirection.to_s.capitalize
        text += indirection.to_s + "\n" + ("-" * name.length) + "\n\n"

        text += ind.doc + "\n\n"

        Puppet::Indirector::Terminus.terminus_classes(ind.name).sort { |a,b| a.to_s <=> b.to_s }.each do |terminus|
            text += terminus.to_s + "\n" + ("+" * terminus.to_s.length) + "\n\n"

            term_class = Puppet::Indirector::Terminus.terminus_class(ind.name, terminus)

            text += Puppet::Util::Docs.scrub(term_class.doc) + "\n\n"
        end
    end

    text
end

reference.header = "This is the list of all indirections, their associated terminus classes, and how you select between them.

In general, the appropriate terminus class is selected by the application for you (e.g., ``puppetd`` would always use the ``rest``
terminus for most of its indirected classes), but some classes are tunable via normal settings.  These will have ``terminus setting``
documentation listed with them.


"
