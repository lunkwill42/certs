#!/bin/bash
#
# certbot-auto-renew.sh -- automate certificate renewal and service restarting
# with a constant CSR / privkey / pubkey to ease key pinning applications.
#
# © 2017 Luis E. Muñoz -- All Rights Reserved

set -e

export LEROOT=${LEROOT:=/etc/letsencrypt}
export LIVEPATH=${LIVEPATH:=${LEROOT}/live}
export SEEDPATH=${SEEDPATH:=${LEROOT}/seed}
export ISSUEPATH=${ISSUEPATH:=${LEROOT}/issue}
export WEBROOT=${WEBROOT:=${LEROOT}/webroot}
export CERTBOT=${CERTBOT:=/usr/bin/certbot}
export MINDAYS=${MINDAYS:=30}
export ACTIVECERT=${ACTIVECERT:=cert-0}
export VERBOSE=${VERBOSE:=''}
export CERTOWNER=${CERTOWNER:=smmta:certs}
export CERTPERMS=${CERTPERMS:=o-rwx}
export FINDOPTS=${FINDOPTS:=}

export SSLCERTCHECK=${SSLCERTCHECK:=/usr/bin/ssl-cert-check}
export CERTBOT=${CERTBOT:=/usr/bin/certbot}

export TEMPFILE=`tempfile`

if [ ! -x ${SSLCERTCHECK} ]; then
  echo ${SSLCERTCHECK} is required -- please install and try again
  exit 255
fi

# This function is responsible for checking and requesting a new certificate
# if applicable

check_and_issue() {

  # Capture the SEED directory we're required to work with
  seedpath=$1

  # The certificate name should be the last component of the path name we
  # were just passed
  certname=`echo $seedpath | sed -e 's,^.*/,,'`

  # Calculate the required paths for this invocation
  livepath=${LIVEPATH}/${certname}
  issuepath=${ISSUEPATH}/${certname}-`date +%Y%m%d`
  csr=${seedpath}/${ACTIVECERT}.csr

  current_cert=${livepath}/cert.pem
  new_cert=${issuepath}/cert.pem

  certbot_params=`cat ${WEBROOT}/${certname}/certbot-params 2>/dev/null`

  if [ ! -z "${VERBOSE}" ]; then
    echo ${WEBROOT}/${certname}/certbot-params
    echo livepath=$livepath
    echo issuepath=$issuepath
    echo seedpath=$seedpath
    echo csr=$csr
    echo new_cert=$new_cert
    echo certname=$certname
    echo certbot-params=${certbot_params}
    echo
    echo
  fi

  # If the certificate is not due to expire before $MINDAYS, then safely skip
  
  if [ ! -f ${current_cert} ] \
    || ${SSLCERTCHECK} -b -x ${MINDAYS} -c ${current_cert} | egrep 'Expiring'
  then

    # If issuepath already exists, we should simply bailout as there's really no
    # need to continue

    if [ -d ${issuepath} ]; then
      echo ${issuepath} already exists -- consider cleaning up if this is an error
      exit 255
    fi

    # Get the current CSR signed. Use the root symlink to point the the
    # webroot to use for authorization. Place the result in a temporary
    # location

    mkdir -p ${issuepath}
    (
      cd ${issuepath}

      if ! ${CERTBOT} certonly --non-interactive         \
                               --quiet                   \
                               --keep-until-expiring     \
                               --csr "${csr}"            \
                               --cert-name "${certname}" \
                               --cert-path "${new_cert}" \
                               ${certbot_params}
      then
        echo ${CERTBOT} failed to issue a certificate
        exit 255
      fi

      # Check that we got the expected files
      if [ ! -f ${new_cert} ]; then
        echo ${new_cert} not found where expected
        exit 255
      fi

      if [ -f 0000_chain.pem ]; then
        mv 0000_chain.pem chain.pem
      else
        echo chain not found where expected
        exit 255
      fi

      if [ -f 0001_chain.pem ]; then
        mv 0001_chain.pem fullchain.pem
      else
        echo fullchain not found where expected
        exit 255
      fi

      # Add symlink to the privkey
      
      ln -s ${seedpath}/${ACTIVECERT}.key privkey.pem

      chown ${CERTOWNER} *.pem ${seedpath}/${ACTIVECERT}.key
      chmod ${CERTPERMS} *.pem ${seedpath}/${ACTIVECERT}.key

      echo YES >> ${TEMPFILE}

      # Leave the current set of certificates ready to go

      rm -rf ${livepath}
      ln -s ${issuepath} ${livepath}
    )

  fi
}

export -f check_and_issue

# Iterate over the list of domains for which we'll need to perform
# verification / issuing. We use this form of command invocation to ensure we
# can process a huge number of certificate directories if we needed to.
# 
# We could also use GNU parallel(1) for large numbers of certificates, to
# speed up the processing. However the non-parallel approach works well for
# tens of certificates.

find ${SEEDPATH} -mindepth 1 -maxdepth 1 -type d ${FINDOPTS}\
  | xargs -L1 -I{} bash -c "check_and_issue {}"

# If certificates were processed successfuly, restart the services that use
# the certificates to be sure the new ones are loaded.

if [ -s ${TEMPFILE} ]; then
  systemctl restart nginx.service
  systemctl restart sendmail.service
  systemctl restart dovecot.service
fi

rm -f ${TEMPFILE}

