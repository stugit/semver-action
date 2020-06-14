#!/bin/bash -x
echo "SOURCE = ${SOURCE}"
echo "DEFAULT_BUMP = ${DEFAULT_BUMP}"
echo "DRYRUN = ${DRYRUN}"
echo "RELEASE_BRANCHES = ${RELEASE_BRANCHES}"
echo "WITH_V = ${WITH_V}"
echo "GITHUB_TOKEN= ${GITHUB_TOKEN}"

echo "SOURCE = ${INPUT_SOURCE}"
echo "DEFAULT_BUMP = ${INPUT_DEFAULT_BUMP}"
echo "DRYRUN = ${INPUT_DRYRUN}"
echo "RELEASE_BRANCHES = ${INPUT_RELEASE_BRANCHES}"
echo "WITH_V = ${INPUT_WITH_V}"
echo "WITH_V = ${INPUT_GITHUB_TOKEN}"


function semver() {
    set -o errexit -o nounset -o pipefail
    
    NAT='0|[1-9][0-9]*'
    ALPHANUM='[0-9]*[A-Za-z-][0-9A-Za-z-]*'
    IDENT="$NAT|$ALPHANUM"
    FIELD='[0-9A-Za-z-]+'
    
    SEMVER_REGEX="\
    ^[vV]?\
    ($NAT)\\.($NAT)\\.($NAT)\
    (\\-(${IDENT})(\\.(${IDENT}))*)?\
    (\\+${FIELD}(\\.${FIELD})*)?$"
    
    PROG=semver
    PROG_VERSION="3.0.0"
    
    USAGE="\
    Usage:
      $PROG bump (major|minor|patch|release|prerel <prerel>|build <build>) <version>
      $PROG compare <version> <other_version>
      $PROG get (major|minor|patch|release|prerel|build) <version>
      $PROG --help
      $PROG --version
    
    Arguments:
      <version>  A version must match the following regular expression:
                 \"${SEMVER_REGEX}\"
                 In English:
                 -- The version must match X.Y.Z[-PRERELEASE][+BUILD]
                    where X, Y and Z are non-negative integers.
                 -- PRERELEASE is a dot separated sequence of non-negative integers and/or
                    identifiers composed of alphanumeric characters and hyphens (with
                    at least one non-digit). Numeric identifiers must not have leading
                    zeros. A hyphen (\"-\") introduces this optional part.
                 -- BUILD is a dot separated sequence of identifiers composed of alphanumeric
                    characters and hyphens. A plus (\"+\") introduces this optional part.
    
      <other_version>  See <version> definition.
    
      <prerel>  A string as defined by PRERELEASE above.
    
      <build>   A string as defined by BUILD above.
    
    Options:
      -v, --version          Print the version of this tool.
      -h, --help             Print this help message.
    
    Commands:
      bump     Bump by one of major, minor, patch; zeroing or removing
               subsequent parts. \"bump prerel\" sets the PRERELEASE part and
               removes any BUILD part. \"bump build\" sets the BUILD part.
               \"bump release\" removes any PRERELEASE or BUILD parts.
               The bumped version is written to stdout.
    
      compare  Compare <version> with <other_version>, output to stdout the
               following values: -1 if <other_version> is newer, 0 if equal, 1 if
               older. The BUILD part is not used in comparisons.
    
      get      Extract given part of <version>, where part is one of major, minor,
               patch, prerel, build, or release.
    
    See also:
      https://semver.org -- Semantic Versioning 2.0.0"
    
    function error {
      echo -e "$1" >&2
      exit 1
    }
    
    function usage-help {
      error "$USAGE"
    }
    
    function usage-version {
      echo -e "${PROG}: $PROG_VERSION"
      exit 0
    }
    
    function validate-version {
      local version=$1
      if [[ "$version" =~ $SEMVER_REGEX ]]; then
        # if a second argument is passed, store the result in var named by $2
        if [ "$#" -eq "2" ]; then
          local major=${BASH_REMATCH[1]}
          local minor=${BASH_REMATCH[2]}
          local patch=${BASH_REMATCH[3]}
          local prere=${BASH_REMATCH[4]}
          local build=${BASH_REMATCH[8]}
          eval "$2=(\"$major\" \"$minor\" \"$patch\" \"$prere\" \"$build\")"
        else
          echo "$version"
        fi
      else
        error "version $version does not match the semver scheme 'X.Y.Z(-PRERELEASE)(+BUILD)'. See help for more information."
      fi
    }
    
    function is-nat {
        [[ "$1" =~ ^($NAT)$ ]]
    }
    
    function is-null {
        [ -z "$1" ]
    }
    
    function order-nat {
        [ "$1" -lt "$2" ] && { echo -1 ; return ; }
        [ "$1" -gt "$2" ] && { echo 1 ; return ; }
        echo 0
    }
    
    function order-string {
        [[ $1 < $2 ]] && { echo -1 ; return ; }
        [[ $1 > $2 ]] && { echo 1 ; return ; }
        echo 0
    }
    
    # given two (named) arrays containing NAT and/or ALPHANUM fields, compare them
    # one by one according to semver 2.0.0 spec. Return -1, 0, 1 if left array ($1)
    # is less-than, equal, or greater-than the right array ($2).  The longer array
    # is considered greater-than the shorter if the shorter is a prefix of the longer.
    #
    function compare-fields {
        local l="$1[@]"
        local r="$2[@]"
        local leftfield=( "${!l}" )
        local rightfield=( "${!r}" )
        local left
        local right
    
        local i=$(( -1 ))
        local order=$(( 0 ))
    
        while true
        do
            [ $order -ne 0 ] && { echo $order ; return ; }
    
            : $(( i++ ))
            left="${leftfield[$i]}"
            right="${rightfield[$i]}"
    
            is-null "$left" && is-null "$right" && { echo 0  ; return ; }
            is-null "$left"                     && { echo -1 ; return ; }
                               is-null "$right" && { echo 1  ; return ; }
    
            is-nat "$left" &&  is-nat "$right" && { order=$(order-nat "$left" "$right") ; continue ; }
            is-nat "$left"                     && { echo -1 ; return ; }
                               is-nat "$right" && { echo 1  ; return ; }
                                                  { order=$(order-string "$left" "$right") ; continue ; }
        done
    }
    
    # shellcheck disable=SC2206     # checked by "validate"; ok to expand prerel id's into array
    function compare-version {
      local order
      validate-version "$1" V
      validate-version "$2" V_
    
      # compare major, minor, patch
    
      local left=( "${V[0]}" "${V[1]}" "${V[2]}" )
      local right=( "${V_[0]}" "${V_[1]}" "${V_[2]}" )
    
      order=$(compare-fields left right)
      [ "$order" -ne 0 ] && { echo "$order" ; return ; }
    
      # compare pre-release ids when M.m.p are equal
    
      local prerel="${V[3]:1}"
      local prerel_="${V_[3]:1}"
      local left=( ${prerel//./ } )
      local right=( ${prerel_//./ } )
    
      # if left and right have no pre-release part, then left equals right
      # if only one of left/right has pre-release part, that one is less than simple M.m.p
    
      [ -z "$prerel" ] && [ -z "$prerel_" ] && { echo 0  ; return ; }
      [ -z "$prerel" ]                      && { echo 1  ; return ; }
                          [ -z "$prerel_" ] && { echo -1 ; return ; }
    
      # otherwise, compare the pre-release id's
    
      compare-fields left right
    }
    
    function command-bump {
      local new; local version; local sub_version; local command;
    
      case $# in
        2) case $1 in
            major|minor|patch|release) command=$1; version=$2;;
            *) usage-help;;
           esac ;;
        3) case $1 in
            prerel|build) command=$1; sub_version=$2 version=$3 ;;
            *) usage-help;;
           esac ;;
        *) usage-help;;
      esac
    
      validate-version "$version" parts
      # shellcheck disable=SC2154
      local major="${parts[0]}"
      local minor="${parts[1]}"
      local patch="${parts[2]}"
      local prere="${parts[3]}"
      local build="${parts[4]}"
    
      case "$command" in
        major) new="$((major + 1)).0.0";;
        minor) new="${major}.$((minor + 1)).0";;
        patch) new="${major}.${minor}.$((patch + 1))";;
        release) new="${major}.${minor}.${patch}";;
        prerel) new=$(validate-version "${major}.${minor}.${patch}-${sub_version}");;
        build) new=$(validate-version "${major}.${minor}.${patch}${prere}+${sub_version}");;
        *) usage-help ;;
      esac
    
      echo "$new"
      exit 0
    }
    
    function command-compare {
      local v; local v_;
    
      case $# in
        2) v=$(validate-version "$1"); v_=$(validate-version "$2") ;;
        *) usage-help ;;
      esac
    
      set +u                        # need unset array element to evaluate to null
      compare-version "$v" "$v_"
      exit 0
    }
    
    
    # shellcheck disable=SC2034
    function command-get {
        local part version
    
        if [[ "$#" -ne "2" ]] || [[ -z "$1" ]] || [[ -z "$2" ]]; then
            usage-help
            exit 0
        fi
    
        part="$1"
        version="$2"
    
        validate-version "$version" parts
        local major="${parts[0]}"
        local minor="${parts[1]}"
        local patch="${parts[2]}"
        local prerel="${parts[3]:1}"
        local build="${parts[4]:1}"
        local release="${major}.${minor}.${patch}"
    
        case "$part" in
            major|minor|patch|release|prerel|build) echo "${!part}" ;;
            *) usage-help ;;
        esac
    
        exit 0
    }
    
    case $# in
      0) echo "Unknown command: $*"; usage-help;;
    esac
    
    case $1 in
      --help|-h) echo -e "$USAGE"; exit 0;;
      --version|-v) usage-version ;;
      bump) shift; command-bump "$@";;
      get) shift; command-get "$@";;
      compare) shift; command-compare "$@";;
      *) echo "Unknown arguments: $*"; usage-help;;
    esac
}    




# MAIN
# config
GITHUB_TOKEN=${INPUT_GITHUB_TOKEN}
default_semvar_bump=${INPUT_DEFAULT_BUMP:-patch}
with_v=${INPUT_WITH_V:-false}
release_branches=${INPUT_RELEASE_BRANCHES:-master}
source=${INPUT_SOURCE:-.}
dryrun=${INPUT_DRY_RUN:-false}

# Was the last merge a feature branch (check merge comment)
if [[ "$(git show -n1 --merges --oneline | grep -c '/feature/')" -ge 1 ]]; then
    default_semvar_bump=minor
fi
echo "default_semvar_bump: ${default_semvar_bump}"

echo "source: ${source}"
cd ${source}
echo "pwd: $(pwd)"

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

tag_commit=$(git rev-list -n 1 $tag)

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
