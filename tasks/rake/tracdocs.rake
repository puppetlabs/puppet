task :tracdocs do
    require 'puppet'
    require 'puppet/util/reference'
    Puppet::Util::Reference.references.each do |ref|
        sh "puppetdoc -m trac -r #{ref.to_s}"
    end 
end

