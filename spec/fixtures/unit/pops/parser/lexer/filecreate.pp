# $Id$

file {
    "/tmp/createatest": making_sure => file, mode => 755;
    "/tmp/createbtest": making_sure => file, mode => 755
}

file {
    "/tmp/createctest": making_sure => file;
    "/tmp/createdtest": making_sure => file;
}
