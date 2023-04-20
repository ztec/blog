---
title: "Nom personnalisé pour vos lib Go"
date: 2023-04-18T02:00:00+02:00
slug: "enlever-github-de-vos-nom-de-package"
tags: ["tech", "go"]
images: [/en/2023/post/remove-github-com-from-golang-package-name/img/promotion-material.png]
---

Récemment, j'ai sorti un petit projet appelé [poulpe.ztec.fr](https://poulpe.ztec.fr).
Ce projet autonome, je l'utilise aussi dans certains de mes projets perso, mais comme librairie. 
Quand je le fais, mes imports ressemblent à ça :

```go
// main.go
import git2.riper.fr/ztec/poulpe
```

J'ai deux problèmes avec cette façon de faire :
  - C'est moche non ? 
  - Si jamais je change l'adresse de mon dépot alors tous les imports précédent sont caducs. (Remarquez le `2` dans le nom déjà)

La majorité des projets open-source sont dépendants de github de cette façon et utilisent directement des imports depuis github.com.
De plus, vous le savez surement, mais github n'est plus notre ami depuis qu'il a été racheté par le mal. Github n'agis plus dans
le bénéfice de l'open source, mais de ses actionnaires. Pire, c'est de plus en plus un réseau social qu'une platform de development.

Afin de promouvoir la pérennisation de l'open-source et du logiciel libre, il devient urgent de réduire voir supprimer cette
dépendance à Github. Avoir des milliers d'imports qui cite spécifiquement Github n'est pas la bonne façon d'y arriver. 


## [Trop long, j'ai pas le temps](#custom-name)
En go, on peut définir le nom d'un package avec un nom de domain dont on gère l'hébergement.
```text
// main.go
import poulpe.ztec.fr
```

## GOPROXY 

Golang viens avec ce qu'on appel les go proxy. Ce sont des intermédiaires entre go et les dépot de nos dépendances. Cet intermédiaire
ajoute deux fonctionalitée importante : 
 - L'immutabilité des package
 - Une protection contre l'indisponibilité.

Pour les utiliser, on définit la variable d'environment `GOPROXY` avec l'url de notre proxy, ou d'un proxy public. 

Bon, c'est cool, on peut perdre Github un moment, nos dépendances sont toujours disponibles. Mais c'est loin d'être parfait. 
D'abord, c'est de la responssabilitée de l'utilisateur de la librarie d'utiliser un proxy ou pas, ensuite on a toujours un soucis
quand notre source de vérité change d'addresse. Et c'est toujours aussi moche qu'avant :sweat:

## Replace

Dans le fichier `go.mod` on peu utiliser la directive `replace` pour spécifiquement remplacer la source d'une lib par une autre. C'est
avant tout utilisé pour pouvoir tester ou utiliser une version différente, mais on peu forcé l'utilisation d'un mirroir de cette façon.

```go
// go.mod
replace github.com/ztec/poulpe v0.3.1 => git2.riper.fr/ztec/poulpe v0.3.1
```
C'est pratique, mais pas vraiment sur le long terme. Je me vois mal le faire pour toutes les libraries charger par mes projet. 
Ça va vite devenir chiant. Et encore, ça reste toujours la responssabilitée de l'utilisateur de la librarie de le faire.
Bonus, c'est encore plus moche qu'avant :joy:

## Instead of

Une autre solution, c'est de changer de manière global l'emplacement des librarie. À la manière de `replace`, on peut 
configurer dans `~/.gitconfig` des miroirs our des sources alternatives. On peu le faire carrément pour tout un domain, comme 
notre cible Github.com. 
C'est principalement utilisé pour changer le protocole, pour des raisons d'identification, mais ça se détourne.

```text
[url "ssh://git@github.com/"]
	insteadOf = https://github.com/
```

ou

```text
[url "https://git2.riper.fr/ztec"]
	insteadOf = https://github.com/ztec
```

C'est utile, mais pose les même problème que la solution du `replace`. 

## Nom personalisé

Si on y réfléchi bien, la seule chose que nous pouvons vraiment posséder sur internet, c'est un nom de domain, et ce qu'il y a dernière.
Glolang permet de rediriger n'importe quel URL vers un packet et c'est réellement facile à faire. 

Par exemple, j'ai changé le nom de mon packet de `git2.riper.fr/ztec/poulpe` en `poulpe.ztec.fr`.

```go
// go.mod
module poulpe.ztec.fr
```

Simplement changer le nom dans le `go.mo` suffit pour le projet lui-même. Mais dès que vous voulez l'importer dans un autre projet,
il faut ajouter un autre élément pour que go retrouve votre librairie. 

Pour que le nouveau nom soit fonctionnel pour tout le monde, il suffit simplement de rajouter une balise meta dans la page
retournée à l'URL du package. Dans l'exemple, cette page: `https://poulpe.ztec.fr`.

```html
 <meta name=go-import content="poulpe.ztec.fr git https://git2.riper.fr/ztec/poulpe.git">
```

Go, lors d'un `go get`, regardera cette page et cherchera pour ces tags `meta` et suivra les instructions qu'il y adedans.

## Quelques bénéfices au nom personalisé

Avec un nom personalisé qui utilise votre domaine, comme l'exemple précédent, vous devenez maitre de votre package. 
Vous avez la liberté de changer l'addresse du depot a loisir, sans en changer le nom. 

En plus, Github n'est plus "nécessaire" ni même mentioné à l'utilisation de votre libraries.
Vous pouvez toujours l'utiliser pour votre dépot, mais vous ne le criez plus sur tous les toits et c'est bien.

En plus d'avoir repris le control de votre packet, vous avez réduit la visibitlitée de github et ce n'est pas rien. 

Merci infiniment de m'avoir lu,\
[Bisoux](/page/bisoux) :kissing:

---
Quelques resources pour aller plus loins :
 - [when-should-i-use-the-replace-directive](https://github.com/golang/go/wiki/Modules#when-should-i-use-the-replace-directive)
 - [are-there-always-on-module-repositories-and-enterprise-proxies](https://github.com/golang/go/wiki/Modules#are-there-always-on-module-repositories-and-enterprise-proxies)
 - [how-to-use-a-private-go-module-in-your-own-project](https://www.digitalocean.com/community/tutorials/how-to-use-a-private-go-module-in-your-own-project)
 - [private-module-repo-auth](https://go.dev/ref/mod#private-module-repo-auth)
 - https://pkg.go.dev/rsc.io/go-import-redirector
 - [Remote_import_paths](https://pkg.go.dev/cmd/go#hdr-Remote_import_paths)
