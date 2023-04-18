---
title: "Custom package name for go libraries"
date: 2023-04-18T02:00:00+02:00
slug: "remote-github-com-from-golang-package-name"
tags: ["tech", "go"]
---

I recently released a small project [poulpe.ztec.fr](https://poulpe.ztec.fr). I personally use this repository as a library i
n one of my other project. When I do so, my import look like this:

```go
// main.go
import gt2.riper.fr/ztec/poulpe
```

I have two issues with that:
 - It ugly, right ?
 - If I ever change the location of my library, this will be broken. (Did you notice the `2` in the name already ?)

Most opensource projects rely on GitHub and simply use `github.com` imports. As you know, GitHub is owned by an evil company now
and do not care for the open source anymore. For the safety of open source we should reduce or remove our dependency to it. 

Having thousands imports that specifically target GitHub.com is not ideal to reach this goal.

## [TL;DR](#custom-name)
We can use our own name as long as we own the hosting at the address
```text
// main.go
import poulpe.ztec.fr
```

## GOPROXY 

Using GOPROXY to specify an intermediary between your `go get` and the vcs such as GitHub. This is nice to ensure you are resilient to GitHub unavailability among other things. 
This does not solve the ugliness nor the name specifying the location tho. 

## Replace

In your `go.mod` the directive `replace` can allow to say where to fetch one package. 

```go
// go.mod
replace github.com/ztec/poulpe v0.3.1 => git2.riper.fr/ztec/poulpe v0.3.1
```

This is usefully but not practical to do on every package. Also, this is the responsibility of the user of the library to do it.

## Instead of

Alternatively, you can globally change where and how to load libraries code based on domains. This is often used to fetch
libraries using ssh instead of https allowing to use credentials. Is is simple as adding this kind of config in your `~/.gitconfig` file

```text
[url "ssh://git@github.com/"]
	insteadOf = https://github.com/
```

or

```text
[url "https://git2.riper.fr/ztec"]
	insteadOf = https://github.com/ztec
```

This is somewhat useful too, but this require the user of the library to do it, and do not give you, the owner, the control. 
You still need GitHub.com to deliver the library

## Custom name

If you think about it, the only thing you can be sure you own, is your domain and what's hosted behind it. Golang allow 
to redirect any url to a proper golang repository. It is easy and give you the control, not the library user. 

For example, I changed my package name from `git2.riper.fr/ztec/poulpe` to `poulpe.ztec.fr`. 

```go
// go.mod
module poulpe.ztec.fr
```

Just doing so will work for the project itself. But anyone that want to use your library won't be able to use it with the new name.
Worst, they will probably have a nightmare to use it as golang checks the name of the module in the `go.mod` file against the import name a
and fail if they do no match

To make it work for every one, you can simply add this in the HTML file at the url `https://poulpe.ztec.fr`.

```html
 <meta name=go-import content="poulpe.ztec.fr git https://git2.riper.fr/ztec/poulpe.git">
```

When doing `go get`, golang will check the url and search for this meta.

## Perks of custom name

With the custom name, you now have full power on the naming of your package. You can also change its location if you wish.
There is no reference to GitHub, although you can still host it on GitHub.
The name use a domain that you probably own.

You also reduce the imprint of GitHub on projects using your library, and can decide to migrate your code wherever you
want.

Thank you reading this,\
[Bisoux](/page/bisoux) :kissing:

---
More detailed informations:
 - [when-should-i-use-the-replace-directive](https://github.com/golang/go/wiki/Modules#when-should-i-use-the-replace-directive)
 - [are-there-always-on-module-repositories-and-enterprise-proxies](https://github.com/golang/go/wiki/Modules#are-there-always-on-module-repositories-and-enterprise-proxies)
 - [how-to-use-a-private-go-module-in-your-own-project](https://www.digitalocean.com/community/tutorials/how-to-use-a-private-go-module-in-your-own-project)
 - [private-module-repo-auth](https://go.dev/ref/mod#private-module-repo-auth)
