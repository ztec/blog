#!/bin/sh
git remote add riper ssh://git@git.riper.fr:22023/ztec/blog.git
git remote add github git@github.com:ztec/blog.git
git fetch riper
git fetch github
git push riper HEAD:main