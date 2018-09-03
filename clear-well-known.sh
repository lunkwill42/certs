#!/bin/bash

# clear-well-known.sh -- Simple utility to clear any remaining ACME dns-01
# authentication tokens left in the domain names we manage.
#
# © 2018 Luis E. Muñoz -- All Rights Reserved

set -e
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Configuration parameters / where to find tools

export LEROOT=${LEROOT:=/etc/letsencrypt}

export SEEDPATH=${SEEDPATH:=${LEROOT}/seed}

export FINDOPTS=${FINDOPTS:=}
export NSUPDATE=${NSUPDATE:=`which nsupdate`}
export NSUPDATE_OPTS=${NSUPDATE_OPTS:=}
export TSIGKEYFILE=${TSIGKEYFILE:=~/mykey.conf}
export MASTER=${MASTER:=}

function clear_acme {
  # Capture the SEED directory we're required to work with
  seedpath=$1

  # The certificate name should be the last component of the path name we
  # were just passed. By convention, this will match the domain name.
  domain=`echo $seedpath | sed -e 's,^.*/,,'`

  echo "Removing existing ACME challenges on ${domain}"

  ((  [ "${MASTER}" == "" ] || echo "server ${MASTER}";
      echo "update delete _acme-challenge.${domain} ${TXT}";
      echo send
  ) | "${NSUPDATE}" -k "${TSIGKEYFILE}" ${NSUPDATE_OPTS}) || \
  echo "Cleanup on ${domain} failed"
}

export -f clear_acme

find ${SEEDPATH} -mindepth 1 -maxdepth 1 -type d ${FINDOPTS}\
| xargs -L1 -I{} bash -c "clear_acme {}"