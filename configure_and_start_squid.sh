#!/bin/bash

envsubst < /etc/squid3/squid.conf > /etc/squid3/squid.conf.sub
mv /etc/squid3/squid.conf.sub /etc/squid3/squid.conf

/usr/local/bin/start_squid.sh

