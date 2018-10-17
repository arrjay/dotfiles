#!/usr/bin/env bash

___quiet_input () {
  local ____set_x='' thestr prompt="${1:-Input string:}" avar="${2:-}"
  printf '%s ' "${prompt}" 1>&2
  chkcmd stty && { command stty -echo ; trap '[ "${____set_x}" ] && set -x ; command stty echo ; trap - INT ; return 2' INT ; }
  case "${-}" in *x*) ____set_x=x ; set +x ;; esac
  read -r thestr || return $?
  [ "${avar}" ] && {
    case "${___printf_supports_v:-}" in
      yes) builtin printf -v "${avar}" '%s' "${thestr}" ;;
      *)   eval "${avar}="'"${thestr}"' ;;
    esac
  } || printf '%s' "${thestr}"
  [ "${____set_x}" ] && set -x
  printf '\n' 1>&2
  chkcmd stty && { command stty echo ; trap - INT ; }
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

_prompt_right () {
  local timestr now timerem
  timestr=''
  now=`date +%s`
  [ "${___CLOUD_SESSION_EXPIRY:-}" ] && {
    let timerem=___CLOUD_SESSION_EXPIRY-now
    [ "${timerem}" -gt 0 ] && let timestr=timerem/60
  }
  printf ' %s ' "${timestr}"
  return "${___pre_prompt_rc}"
}

___cloud_prompt_command () {
  [ "${___CLOUD_SESSION_ARN:-}" ] && echo "${___CLOUD_SESSION_ARN}"
}
___prompt_command_list=('___cloud_prompt_command' "${___prompt_command_list[@]}")

_aws_signin () {
  local passrec line askmfa opt OPTARG OPTIND mfapin profile ____set_x cmd userarn accountid role assumerole_data rolesess expiry
  passrec="${___AWS_PASS_ITEM:-}" ; askmfa=''

  while getopts "P:p:m:Mc:" opt "${@}" ; do case "${opt}" in
    P) passrec="${OPTARG}" ;;
    p) profile="${OPTARG}" ; askmfa='yes' ;;
    M) askmfa='yes' ;;
    m) AWS_MFA_SERIAL="${OPTARG}" && _cloud_authkey AWS_MFA_SERIAL ;;
    c) mfapin="${OPTARG}" ;;
    *) { ___error_msg "${FUNCNAME[0]}: [-P pass record][-p aws profile][-m mfa_arn][-c pin][-M]" ; return 1 ; } ;;
  esac ; done

  # hook if we need any preprocessing
  ___chkdef ___aws_pre_signin && ___aws_pre_signin

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

  # if we have aws, get user information now.
  { chkcmd aws && chkcmd jq ; } && {
    userarn=`aws iam get-user | jq -r .User.Arn`
  }

  # if asked for a profile, assume-role to get the session keys. needs aws, jq, and _aws_profile2acct though.
  [ "${profile}" ] && {
    for cmd in jq aws ; do
      chkcmd "${cmd}" || { ___error_msg "AWS STS profile switching requires ${cmd} command to be installed" ; return 1 ; }
    done
    ___chkdef _aws_profile2acct || { ___error_msg "AWS STS profile switching requires _aws_profile2acct definition to return acct id, role" ; return 1 ; }
    read -r accountid role < <(_aws_profile2acct "${profile}")
    { [ "${accountid}" ] && [ "${role}" ] ; } || { ___error_msg "failure getting aws profile account/role" ; return 1 ; }
    rolesess="${___host}"
    chkcmd date && rolesess="${rolesess}-`date +%s`"
    case "${-}" in *x*) ____set_x=x ; set +x ;; esac
      mfapin=`___quiet_input "AWS MFA PIN:"`
      assumerole_data=`aws sts assume-role --role-arn "arn:aws:iam::${accountid}:role/${role}" --role-session-name "${rolesess}" \
                       --serial-number "${AWS_MFA_SERIAL}" --token-code "${mfapin}"`
      # replace tokens with results of assume-role call.
      read -r AWS_SESSION_TOKEN AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY userarn expiry < <(echo "${assumerole_data}" | jq -r \
         '. | "\(.Credentials.SessionToken) \(.Credentials.AccessKeyId) \(.Credentials.SecretAccessKey) \(.AssumedRoleUser.Arn) \(.Credentials.Expiration)"')
    [ "${____set_x}" ] && set -x
    [ "${expiry}" ] && ___chkdef date && ___CLOUD_SESSION_EXPIRY="`date --date "${expiry}" +%s`"
    ___CLOUD_AUTH_KEYS=("${___CLOUD_AUTH_KEYS[@]}" 'AWS_SESSION_TOKEN' '___CLOUD_SESSION_EXPIRY')
  }

  # export the signin keys at this point
  # shellcheck disable=SC2163
  [ "${___CLOUD_AUTH_KEYS[0]}" ] && export "${___CLOUD_AUTH_KEYS[@]}"

  # if we have a post-auth hook, call it now
  ___chkdef ___aws_post_signin && ___aws_post_signin
}

___aws_post_signin () {
  # if we did not previously have a region, set it to us-east-1.
  [ "${AWS_DEFAULT_REGION}" ] || { export AWS_DEFAULT_REGION='us-east-1' ; ___CLOUD_AUTH_KEYS=("${___CLOUD_AUTH_KEYS[@]}" 'AWS_DEFAULT_REGION') ; }
}
