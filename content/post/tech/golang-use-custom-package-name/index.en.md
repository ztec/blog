---
title: "Custom package name for go libraries"
date: 2023-04-18T02:00:00+02:00
slug: "remove-github-com-from-golang-package-name"
tags: ["tech", "go", "IA-helped"]
---

I recently released a small project called [poulpe.ztec.fr](https://poulpe.ztec.fr). 
I personally use this repository as a library in one of my other projects. When I do so, my import statement looks like this:

```go
// main.go
import gt2.riper.fr/ztec/poulpe
```

I have two issues with this approach:
 - It ugly, right ?
 - If I ever change the location of my library, the import statement will break. (You may have already noticed the '2' in the name.)

Most open-source projects rely on GitHub and simply use 'github.com' imports. 
However, as you may know, GitHub is now owned by a company doesn't care about open-source anymore. 
To promote the safety of open-source, we should reduce or remove our dependency on GitHub.

Having thousands of imports that specifically target GitHub.com is not ideal for achieving this goal.


## [TL;DR](#custom-name)
We can use our own domain name as long as we have ownership of the hosting at that address.
```text
// main.go
import poulpe.ztec.fr
```

## GOPROXY 

You can use `GOPROXY` to specify an intermediary between your `go get` command and the version control system (VCS), such as GitHub. 
This is a nice way to ensure resiliency to GitHub unavailability, among other things.
However, using `GOPROXY` does not solve the issues of ugliness and specifying the location by name.

## Replace

In your `go.mod` file, you can use the `replace` directive to specify where to fetch a package.

```go
// go.mod
replace github.com/ztec/poulpe v0.3.1 => git2.riper.fr/ztec/poulpe v0.3.1
```

This is useful, but not practical to do on every package. Additionally, it is the responsibility of the library user to do so.

## Instead of

Alternatively, you can globally change where and how to load library code based on domains. This is often used to fetch
libraries using ssh instead of https, allowing the use of credentials. It is as simple as adding this kind of configuration to your `~/.gitconfig` file.


```text
[url "ssh://git@github.com/"]
	insteadOf = https://github.com/
```

or

```text
[url "https://git2.riper.fr/ztec"]
	insteadOf = https://github.com/ztec
```

This is somewhat useful as well, but it requires the library user to perform the task and does not give you, the owner, control. 
Additionally, you still need GitHub.com to deliver the library.

## Custom name

If you think about it, the only thing you can be sure you own is your domain and what's hosted behind it. Golang allows 
you to redirect any URL to a proper Golang repository. It is easy and gives you control, not the library user.

For example, I changed my package name from `git2.riper.fr/ztec/poulpe` to `poulpe.ztec.fr`.

```go
// go.mod
module poulpe.ztec.fr
```

Just doing so will work for the project itself. However, anyone who wants to use your library won't be able to use it with the new name.
Worse, they will probably have a nightmare to use it as Golang checks the name of the module in the `go.mod` file against the import name 
and fails if they do not match.

To make it work for everyone, you can simply add this to the HTML file at the URL `https://poulpe.ztec.fr`.

```html
 <meta name=go-import content="poulpe.ztec.fr git https://git2.riper.fr/ztec/poulpe.git">
```

When doing `go get`, Golang will check the URL and search for this meta.

## Perks of custom name
With the custom name, you now have full power over the naming of your package. You can also change its location if you wish. 
There is no reference to GitHub, although you can still host it on GitHub. 
The name uses a domain that you probably own.

You also reduce the imprint of GitHub on projects using your library and can decide to migrate your code wherever you want.

Thank you reading this,\
[Bisoux](/page/bisoux) :kissing:

---
More detailed informations:
 - [when-should-i-use-the-replace-directive](https://github.com/golang/go/wiki/Modules#when-should-i-use-the-replace-directive)
 - [are-there-always-on-module-repositories-and-enterprise-proxies](https://github.com/golang/go/wiki/Modules#are-there-always-on-module-repositories-and-enterprise-proxies)
 - [how-to-use-a-private-go-module-in-your-own-project](https://www.digitalocean.com/community/tutorials/how-to-use-a-private-go-module-in-your-own-project)
 - [private-module-repo-auth](https://go.dev/ref/mod#private-module-repo-auth)
 - https://pkg.go.dev/rsc.io/go-import-redirector
 - [Remote_import_paths](https://pkg.go.dev/cmd/go#hdr-Remote_import_paths)
