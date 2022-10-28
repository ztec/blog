#!/bin/sh
set -ex
git remote add riper ssh://git@git.riper.fr:22023/ztec/blog.git
git remote add github git@github.com:ztec/blog.git
git fetch riper
git fetch github
git merge --ff-only github/main
git merge --ff-only riper/main
git push github HEAD:main
git push riper HEAD:main
