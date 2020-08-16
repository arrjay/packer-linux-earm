#!/usr/bin/env bash

cat /run/untrustedhost/nut/ups.conf.d/*.conf > /run/untrustedhost/nut/ups.conf
chgrp nut /run/untrustedhost/nut/ups.conf
chmod 0660 /run/untrustedhost/nut/ups.conf
