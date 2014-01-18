# $Id$

file {
    "/tmp/multipleinstancesa": making_sure => file, mode => 755;
    "/tmp/multipleinstancesb": making_sure => file, mode => 755;
    "/tmp/multipleinstancesc": making_sure => file, mode => 755;
}
