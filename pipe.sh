#!/bin/sh
exec curl --data "key=$1" --data-urlencode "message@-" "$2"
