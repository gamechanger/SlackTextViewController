#!/bin/bash

##
## The Definitions
##

podspecFile=../SlackTextViewController.podspec
newVersionNumber="0.0.0"
scriptDirectory=`dirname "$0"`
gitTag="0.0.0"

#
# Convenience functions
echoerr() {
    echo "$1" >&2
}

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

usage() {
    echo "usage: publish-version.sh <version number>"
    echo "    - <version number> is 3 dot-separated integers (e.g. 1.2.3)"
    echo "    - Can be run from anywhere within the repository."
    echo "    - Must be on branch master with zero uncommitted or untracked files."
    echo "    - podspecFile must exist at the specified location relative to the script."
}

preflight_fail() {
    echoerr "$1"
    usage
    exit 1
}

#
# Function for checking that all parameters and the environment are in order
preflight_checks() {
    #
    # Check for correct number of arguments (1)
    if [ "$#" -ne 1 ]; then
        preflight_fail "Incorrect number of arguments."
    fi

    newVersionNumber=$1

    # #
    # # Check that the argument is a properly formatted version number (x.y.z)
    # if [[ ! $newVersionNumber =~ ^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$ ]]; then
    #     preflight_fail "Argument is not a valid version number (x.y.z)"
    # fi

    #
    # Make sure the current branch is set to master
    currentBranch=$(git branch | sed -n '/\* /s///p')
    if [ "$currentBranch" != "master" ]; then
        preflight_fail "You are not on master.  You need to be on master to run this script."
    fi

    #
    # Make sure there are no uncommitted or untracked files
    untrackedFile=$(git status --porcelain | wc -l)
    if [ $untrackedFile -ne 0 ]; then
        preflight_fail "Uncommitted or untracked files are detected.  Please commit them or stash them before you run this script."
    fi

    #
    # Check that podspecFile exists
    if [ ! -e $podspecFile ]; then
        preflight_fail "Cannot find file $podspecFile"
    fi
}

#
# Function for exiting with an error and rolling back changes
error_exit() {
    echoerr $2

    # delete the tag
    if [ $1 -ge 4 ]; then
        echo "Removing tag locally"
        git tag -d $gitTag
        if [ $1 -ge 5 ]; then
            echo "...and removing from origin"
            git push origin :refs/tags/$gitTag
        fi
    fi

    # undo the commit of the podspec file
    if [ $1 -ge 2 ]; then
        echo "Rolling HEAD back to previous commit"
        git reset --hard HEAD~1
        if [ $1 -ge 3 ]; then
            echo "...and pushing rollback to origin"
            git push --force origin master
        fi
    fi

    # replace saved podspec file
    if [ $1 -ge 1 ]; then
        echo "Restoring podspec file"
        git checkout $podspecFile
    fi

    exit 1
}

##
## The Work
##

#
# Change to the directory containing the script, pop out on exit
echo "Changing directory to $scriptDirectory"
pushd $scriptDirectory
trap popd 0 1 2 3 15

#
# Check the input and environment
preflight_checks "$@"

#
# Generate new podspec file with new version number
echo "Generating new podspec"
ruby generate-podspec.rb $newVersionNumber > $podspecFile || error_exit 1 "Failed to generate new podspec file"

#
# Stage new podspec file for commit
echo "Staging podspec for commit"
git add $podspecFile

#
# Commit the new podspec
echo "Committing podspec file"
git commit -m "Update podspec" || error_exit 1 "Failed to run command: git commit -m ..."

#
# Push the commit to origin master
echo "Pushing commit to origin master"
git push origin master || error_exit 2 "Failed to run command: git push origin master"

#
# Create a git tag for the new version
gitTag=$newVersionNumber
echo "Creating tag for release: $gitTag"
git tag -a $gitTag -m "Create tag" || error_exit 3 "Failed to run command: git tag -a $gitTag -m 'Create tag'"

#
# Push the new tag to remote
echo "Pushing tag to remote"
git push origin $gitTag || error_exit 4 "Failed to run command: git push origin $gitTag"

#
# Finally, push the new podspec file to gcpodspecs repo
echo "Pushing new podspec to gcpodspecs repo"
pod repo push --allow-warnings --sources='git@github.com:gamechanger/gcpodspecs.git' gamechanger $podspecFile || error_exit 5 "Failed to push podspec to gcpodspecs repo"
