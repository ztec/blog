#!/bin/sh
git remote rename origin riper
git remote add github git@github.com:ztec/blog.git
git fetch riper
git fetch github
git push github HEAD:main