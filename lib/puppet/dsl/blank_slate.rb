
class Puppet::DSL::BlankSlate
  instance_methods.each do |m|
    undef_method m unless m =~ /^__/ or m =~ /instance_eval/ or m =~ /object_id/ or m =~ /send/
  end

end

