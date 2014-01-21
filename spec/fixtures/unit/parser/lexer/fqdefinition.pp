define one::two($making_sure) {
    file { "/tmp/fqdefinition": making_sure => $making_sure }
}

one::two { "/tmp/fqdefinition": making_sure => file }
