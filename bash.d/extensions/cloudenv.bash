#!/usr/bin/env bash

___quiet_input () {
  local ____set_x='' thestr prompt="${1:-Input string:}" avar="${2:-}"
  printf '%s ' "${prompt}" 1>&2
  chkcmd stty && command stty -echo
  case "${-}" in *x*) ____set_x=x ; set +x ;; esac
  read -r thestr
  [ "${avar}" ] && {
    case "${___printf_supports_v:-}" in
      yes) builtin printf -v "${avar}" '%s' "${thestr}" ;;
      *)   eval "${avar}=\'${thestr}\'" ;;
    esac
  } || printf '%s' "${thestr}"
  [ "${____set_x}" ] && set -x
  printf '\n' 1>&2
  chkcmd stty && command stty echo
  return 0
}

_cloud_logout () {
  unset "${___CLOUD_AUTH_KEYS[@]}"
  ___CLOUD_AUTH_KEYS=()
}

_cloud_authkey () {
  local key="${1}"
  [ "${key}" ] && ___CLOUD_AUTH_KEYS=("${___CLOUD_AUTH_KEYS[@]}" "${key}")
}

_cloud_authprompt () {
  :
}

_aws_signin () {
  local passrec line askmfa opt OPTARG OPTIND mfapin profile ____set_x cmd
  passrec="${___AWS_PASS_ITEM:-}" ; askmfa=''

  while getopts "P:p:m:Mc:" opt "${@}" ; do case "${opt}" in
    P) passrec="${OPTARG}" ;;
    p) profile="${OPTARG}" ; askmfa='yes' ;;
    M) askmfa='yes' ;;
    m) AWS_MFA_SERIAL="${OPTARG}" && _cloud_authkey AWS_MFA_SERIAL ;;
    c) mfapin="${OPTARG}" ;;
    *) { ___error_msg "${FUNCNAME[0]}: [-P pass record][-p aws profile][-m mfa_arn][-c pin][-M]" ; return 1 ; } ;;
  esac ; done

  # if we have pass, get the bits via pass. or ask for them. grab the MFA token from pass if here.
  [ "${passrec}" ] && {
    chkcmd pass || { ___error_msg "cannot find pass command" ; return 1 ; }
    case "${-}" in *x*) ____set_x=x ; set +x ;; esac
    while read -r line ; do
      case "${line}" in
        "AWS_MFA_SERIAL: "*)        AWS_MFA_SERIAL="${line#AWS_MFA_SERIAL: }"
                                    ___CLOUD_AUTH_KEYS=("${___CLOUD_AUTH_KEYS[@]}" 'AWS_MFA_SERIAL')        ;;
        "AWS_SECRET_ACCESS_KEY: "*) AWS_SECRET_ACCESS_KEY="${line#AWS_SECRET_ACCESS_KEY: }"
                                    ___CLOUD_AUTH_KEYS=("${___CLOUD_AUTH_KEYS[@]}" 'AWS_SECRET_ACCESS_KEY') ;;
        "AWS_ACCESS_KEY_ID: "*)     AWS_ACCESS_KEY_ID="${line#AWS_ACCESS_KEY_ID: }"
                                    ___CLOUD_AUTH_KEYS=("${___CLOUD_AUTH_KEYS[@]}" 'AWS_ACCESS_KEY_ID')     ;;
      esac
    done < <(pass ls "${passrec}")
    [ "${____set_x}" ] && set -x
  }

  # in case we did not load keys via pass, ask for them.
  case "${-}" in *x*) ____set_x=x ; set +x ;; esac
  { [ "${AWS_ACCESS_KEY_ID}" ] && [ "${AWS_SECRET_ACCESS_KEY}" ] ; } || {
    [ "${____set_x}" ] && set -x
    ___quiet_input "AWS Access Key ID:"     "AWS_ACCESS_KEY_ID"     && ___CLOUD_AUTH_KEYS=("${___CLOUD_AUTH_KEYS[@]}" 'AWS_ACCESS_KEY_ID')
    ___quiet_input "AWS Secret Access Key:" "AWS_SECRET_ACCESS_KEY" && ___CLOUD_AUTH_KEYS=("${___CLOUD_AUTH_KEYS[@]}" 'AWS_SECRET_ACCESS_KEY')
  }
  [ "${____set_x}" ] && set -x

  # if we need an mfa serial, but don't have it, ask.
  [ "${askmfa}" ] || {
    [ "${AWS_MFA_SERIAL}" ] || { ___quiet_input "AWS MFA ARN (Serial):" "AWS_MFA_SERIAL" && \
                                 ___CLOUD_AUTH_KEYS=("${___CLOUD_AUTH_KEYS[@]}" 'AWS_MFA_SERIAL') ; }
  }

  # if asked for a profile, assume-role to get the session keys. needs aws, jq, and _aws_profile2acct though.
  [ "${profile}" ] && {
    for cmd in jq aws ; do
      chkcmd "${cmd}" || { ___error_msg "AWS STS profile switching requires ${cmd} command to be installed" ; return 1 ; }
    done
    ___chkdef _aws_profile2acct || { ___error_msg "AWS STS profile switching requires _aws_profile2acct definition to return acct id, role" ; return 1 ; }
  }

  # export the signin keys at this point
  export "${___CLOUD_AUTH_KEYS[@]}"
}
