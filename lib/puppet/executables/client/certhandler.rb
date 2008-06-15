
module Puppet
    module Executables
        module Client
            class CertHandler
                attr_writer :wait_for_cert, :one_time
                attr_reader :caclient, :new_cert
                
                def initialize(wait_time, is_one_time)
                    @wait_for_cert = wait_time
                    @one_time = is_one_time
                    @new_cert = false

                    @caclient = Puppet::Network::Client.ca.new()
                end

                # Did we just read a cert?
                def new_cert?
                    new_cert
                end
                
                # Read, or retrieve if necessary, our certificate.  Returns true if we retrieved
                # a new cert, false if the cert already exists.
                def read_retrieve 
                    #NOTE: ACS this is checking that a file exists, maybe next time just do that?
                    unless read_cert 
                        # If we don't already have the certificate, then create a client to
                        # request one.  Use the special ca stuff, don't use the normal server and port.
                        retrieve_cert
                    end

                    ! new_cert?
                end

                def retrieve_cert
                    while true do
                       begin
                           if caclient.request_cert 
                               break if read_new_cert
                           else
                               Puppet.notice "Did not receive certificate"
                               if @one_time 
                                   Puppet.notice "Set to run 'one time'; exiting with no certificate"
                                   exit(1)
                               end
                           end
                       rescue StandardError => detail
                          Puppet.err "Could not request certificate: %s" % detail.to_s
                          exit(23) if @one_time
                       end

                       sleep @wait_for_cert 
                    end
                end

                def read_cert
                     caclient.read_cert
                end

                def read_new_cert
                    if caclient.read_cert
                        # If we read it in, then we need to get rid of our existing http connection.
                        # The @new_cert flag will help us do that, in that it provides a way
                        # to notify that the cert status has changed.
                        @new_cert = true
                        Puppet.notice "Got signed certificate"
                    else
                        Puppet.err "Could not read certificates after retrieving them"
                        exit(34) if @one_time
                    end

                    return @new_cert
                end
            end
        end
    end
end
