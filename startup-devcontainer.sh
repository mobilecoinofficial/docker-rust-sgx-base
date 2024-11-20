#!/bin/bash

opt_owner=$(stat -c %U /opt)

if [[ "${opt_owner}" != "sentz" ]]
then
    echo "Changing /opt owner to sentz...(this may take a while)"
    sudo chown -R sentz:sentz /opt
fi
