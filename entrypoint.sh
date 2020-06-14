#!/bin/bash
SOURCE=${INPUT_SOURCE}
DEFAULT_BUMP=${INPUT_DEFAULT_BUMP}
DRYRUN=${INPUT_DRYRUN}
RELEASE_BRANCHES=${INPUT_RELEASE_BRANCHES}
WITH_V=${INPUT_WITH_V}
GITHUB_TOKEN=${INPUT_GITHUB_TOKEN}

# MAIN
# config
default_semvar_bump=${DEFAULT_BUMP:-patch}
with_v=${WITH_V:-false}
release_branches=${RELEASE_BRANCHES:-master}
source=${SOURCE:-.}
dryrun=${DRY_RUN:-false}

echo "source: ${source}"
cd ${source}
echo "pwd: $(pwd)"
ls -alrt

# Was the last merge a feature branch (check merge comment)
if [[ "$(git show -n1 --merges --oneline | grep -c '/feature/')" -ge 1 ]]; then
    default_semvar_bump=minor
fi
echo "default_semvar_bump: ${default_semvar_bump}"

pre_release="true"
IFS=',' read -ra branch <<< "$release_branches"
for b in "${branch[@]}"; do
    echo "Is $b a match for ${GITHUB_REF#'refs/heads/'}"
    if [[ "${GITHUB_REF#'refs/heads/'}" =~ $b ]]
    then
        pre_release="false"
    fi
done

# KT - Allow override pre_release
pre_release=${PRE_RELEASE:-false}
echo "pre_release = $pre_release"

# fetch tags
git fetch --tags

# get latest tag that looks like a semver (with or without v)
tag=$(git for-each-ref --sort=-v:refname --count=1 --format '%(refname)' refs/tags/[0-9]*.[0-9]*.[0-9]* refs/tags/v[0-9]*.[0-9]*.[0-9]* | cut -d / -f 3-)

if [[ ! -z $tag ]];
then
  tag_commit=$(git rev-list -n 1 $tag)
fi

# get current commit hash for tag
commit=$(git rev-parse HEAD)

if [ "$tag_commit" == "$commit" ]; then
    echo "No new commits since previous tag. Skipping..."
    echo ::set-output name=tag::$tag
    exit 0
fi

# if there are none, start tags at 0.0.0
if [ -z "$tag" ]
then
    log=$(git log --pretty='%B')
    tag=0.0.0
else
    log=$(git log $tag..HEAD --pretty='%B')
fi

echo $log

# get commit logs and determine home to bump the version
# supports #major, #minor, #patch (anything else will be 'minor')
case "$log" in
    *#major* ) new=$(semver bump major $tag);;
    *#minor* ) new=$(semver bump minor $tag);;
    *#patch* ) new=$(semver bump patch $tag);;
    * ) new=$(semver bump `echo $default_semvar_bump` $tag);;
esac

# did we get a new tag?
if [ ! -z "$new" ]
then
	# prefix with 'v'
	if $with_v
	then
			new="v$new"
	fi

	if $pre_release
	then
			new="$new-${commit:0:7}"
	fi
fi

# set outputs
echo ::set-output name=new_tag::$new

# use dry run to determine the next tag
if $dryrun
then
    echo ::set-output name=tag::$tag
    exit 0
fi 

echo ::set-output name=tag::$new


if $pre_release
then
    echo "This branch is not a release branch. Skipping the tag creation."
    exit 0
fi

# push new tag ref to github
dt=$(date '+%Y-%m-%dT%H:%M:%SZ')
full_name=$GITHUB_REPOSITORY
git_refs_url=$(jq .repository.git_refs_url $GITHUB_EVENT_PATH | tr -d '"' | sed 's/{\/sha}//g')

echo "$dt: **pushing tag $new to repo $full_name"

curl -s -X POST $git_refs_url \
-H "Authorization: token $GITHUB_TOKEN" \
-d @- << EOF
{
  "ref": "refs/tags/$new",
  "sha": "$commit"
}
EOF
