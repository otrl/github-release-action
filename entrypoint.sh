#!/bin/bash

set -e

##############################################################################
# Globals:
#   None
# Arguments:
#   latest_tag
#   release_name
#   release_notes
# Returns:
#   The request payload for the `create release` Github API
##############################################################################
create_release_request_payload() {
    cat <<EOF
        {
            "tag_name": "$1",
            "target_commitish": "master",
            "name": "$2",
            "body": "$3",
            "draft": false,
            "prerelease": false
        }
EOF
}

##############################################################################
# Builds and publishes a Github release. If there is already a release for the
# given tag, the scrip is going to forece update it. The release consists of
# the followings:
#   - release name: [repo_name] - [latest_tag]
#   - release notes: The list of commits that introduced in the release. Each
#                    item consists of the Markdown link to JIRA ticket, the
#                    commit message and the PR number
#
# Globals:
#   GITHUB_API_TOKEN - Github API access token.
# Arguments:
#   None
# Returns:
#   None
##############################################################################
main() {
    #repository_name=$(basename "$(git rev-parse --show-toplevel)")
    repository_name=$GITHUB_REPOSITORY
#    latest_tag=$(git describe --tags --abbrev=0)
#    previous_tag=$(git describe --abbrev=0 --tags "$(git rev-list --tags --skip=1 --max-count=1)" || true)
#    if [ -z $previous_tag ]; then
#        # look for changes since the first commit
#        previous_tag=$(git rev-list --max-parents=0 HEAD)
#    fi
    latest_tag=$(git tag --sort=committerdate | tail -1)
    previous_tag=$(git tag --sort=committerdate | tail -2 | head -1)
    echo "latest_tag: $latest_tag"
    echo "previous_tag: $previous_tag"

    tag1=$(git rev-list -n 1 "$previous_tag")
    tag2=$(git rev-list -n 1 "$latest_tag")
    commits=$(git log "$tag1" -- "$tag2" --oneline)

    #commits=$(git log "${previous_tag}".."${latest_tag}" --oneline)
    if [ $repository_name = "otrl/aws-rail-deployment" ]; then
      release_name="$latest_tag"
    else
      release_name="$repository_name - $latest_tag"
    fi

    # 1. Extracts the commit messages and drops the commit hash
    # 2. Builds the Markdown (MD) - replaces CORE-xxxx, OPS-xxxx and CT-xxxx with the MD link for the JIRA ticket
    # 3. Remove break line
    # NOTE: If you are on a Mac you probably need to use `gsed` instead of the build in `sed`
    release_notes=$(echo "$commits" \
        | grep -E -io 'core-.+|ops-.+|ct-.+' \
        | sed -E 's/(core-[0-9]+|ops-[0-9]+|ct-[0-9]+)\]?\:?\s*(.*\)?$)/[\1](https:\/\/ontrackretail.atlassian.net\/browse\/\1): \2<br\/>/gI' \
        | tr -d \\n)

    echo -e "\e[33mRelease Info \e[39m"
    printf "\tRepository: %s \n" "$repository_name"
    printf "\tRelease name: %s \n" "$release_name"
    printf "\tLatest tag: %s \n" "$latest_tag"
    printf "\tPrevious tag: %s \n" "$previous_tag"
    echo
    echo -e "\e[33m Commits introduced \e[39m"

    IFS=$'\n'
    for c in ${commits}; do printf "\t%s \n" "$c"; done
    IFS=' '

	echo
	echo "RELEASE NOTES"
    echo "$release_notes"

    echo
    echo -e "\e[33m Request payload \e[39m"
    create_release_request_payload "$latest_tag" "$release_name" "$release_notes"

    create_release_response=$(curl \
      -d "$(create_release_request_payload "$latest_tag" "$release_name" "$release_notes")" \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Content-Type: application/json" \
      -X POST https://api.github.com/repos/"${repository_name}"/releases)

    already_exists=$(echo "$create_release_response" | grep "already_exists" || :) \

    if [ -z "$already_exists" ]; then
        echo
        echo -e "\e[32m New release has been created: $release_name \e[39m"
        echo
    else
        echo
        echo -e "\e[220m A release for $latest_tag tag already exists, updating release... \e[39m"
        echo

        get_release_response=$(curl \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -X GET https://api.github.com/repos/"${repository_name}"/releases/tags/"$latest_tag")

        release_id=$(echo "$get_release_response" | grep '"id":' | head -1 | grep -o '[0-9]\+')

        update_release_response=$(curl \
            -d "$(create_release_request_payload "$latest_tag" "$release_name" "$release_notes")" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -X PATCH https://api.github.com/repos/"${repository_name}"/releases/"${release_id}")

        echo -e "\e[32m Release has been updated: $release_name \e[39m"
    fi
}

main "$@"
