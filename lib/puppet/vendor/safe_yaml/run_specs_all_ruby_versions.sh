#!/bin/bash

[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm"

rvm use 1.8.7@safe_yaml
rake spec

rvm use 1.9.2@safe_yaml
YAMLER=syck rake spec

rvm use 1.9.3@safe_yaml
YAMLER=syck rake spec

rvm use 1.9.2@safe_yaml
YAMLER=psych rake spec

rvm use 1.9.3@safe_yaml
YAMLER=psych rake spec

rvm use 2.0.0@safe_yaml
YAMLER=psych rake spec
