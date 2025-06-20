#!/bin/sh

set -e

USER_POOL=$1
GROUP=$2
ACTION=$3

echo "Fetching users from Cognito User Pool: $USER_POOL"

export AWS_DEFAULT_REGION="$AWS_REGION"

if [[ -z "$AWS_ACCESS_KEY_ID" ]]; then
  echo "You must provide the AWS_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
  echo "You must provide the AWS_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [[ -z "$AWS_DEFAULT_REGION" ]] ; then
  echo "You must provide the AWS_REGION environment variable."
  exit 1
fi

if [[ -z "$USER_POOL" ]]; then
  echo "You must provide the user pool ID."
  exit 1
fi

if [[ -z "$GROUP" ]]; then
  echo "You must provide the group"
  exit 1
fi

get_users () {
    local list_result;
    local usernames;
    if [[ -z $PROFILE ]]; then
        list_result=$(aws cognito-idp list-users --user-pool-id $USER_POOL)
    else
        list_result=$(aws cognito-idp list-users --user-pool-id $USER_POOL --profile $PROFILE)
    fi
    exit_status=$?
    usernames=$(echo "$list_result" | jq -r '.Users[] | .Username')
    echo "$usernames"
    return $exit_status
}

usernames=$(get_users)

for username in $usernames; do
    username=$(echo $username | tr -d " \t\n\r")
    if [[ $username == "super" ]]; then
        echo "Skipping super user $username"
        continue
    fi
    if [[ $ACTION == "remove" ]]; then
        echo "Removing user $username from group $GROUP"
        aws cognito-idp admin-remove-user-from-group --user-pool-id $USER_POOL --username $username --group-name $GROUP
    elif [[ $ACTION == "add" ]]; then
        echo "Adding user $username to group $GROUP"
        aws cognito-idp admin-add-user-to-group --user-pool-id $USER_POOL --username $username --group-name $GROUP
    else
        echo "Invalid action: $ACTION. Use 'add' or 'remove'."
        exit 1
    fi
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo "Something went wrong: $username $GROUP"
        exit $exit_status
    fi
done
