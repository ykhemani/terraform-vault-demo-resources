#!/bin/bash

%{for token in approle_tokens ~}
VAULT_TOKEN=${token} vault token lookup
%{ endfor ~}

