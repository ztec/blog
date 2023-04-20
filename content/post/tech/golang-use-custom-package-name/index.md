---
title: "Nom personnalisé pour vos lib Go"
date: 2023-04-18T02:00:00+02:00
slug: "enlever-github-de-vos-nom-de-package"
tags: ["tech", "go", "IA-helped"]
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
- C'est moche, non ?
- Si jamais je change l'adresse de mon dépôt, alors tous les imports précédents seront caducs. (Remarquez le `2` dans le nom déjà)

La majorité des projets open-source dépendent de Github de cette façon et utilisent directement des imports depuis github.com.
De plus, vous le savez sûrement, mais Github n'est plus notre ami depuis qu'il a été racheté par le mal. 
Github n'agit plus dans le bénéfice de l'open source, mais de ses actionnaires. 
Pire, c'est de plus en plus un réseau social plutôt qu'une plateforme de développement.

Afin de promouvoir la pérennisation de l'open-source et du logiciel libre, il devient urgent de réduire, 
voire de supprimer cette dépendance à Github. 
Avoir des milliers d'imports qui citent spécifiquement Github n'est pas la bonne façon d'y arriver.



## [Trop long, j'ai pas le temps](#custom-name)
En Go, il est possible de définir le nom d'un package avec un nom de domaine dont on gère l'hébergement.
```text
// main.go
import poulpe.ztec.fr
```

## GOPROXY 

Go vient avec ce que l'on appelle les "Go proxy". Ce sont des intermédiaires entre Go et les dépôts de nos dépendances. 
Ces intermédiaires ajoutent deux fonctionnalités importantes :
- L'immutabilité des packages
- Une protection contre l'indisponibilité.

Pour les utiliser, on définit la variable d'environnement `GOPROXY` avec l'URL de notre proxy ou d'un proxy public.

C'est cool, on peut perdre Github un moment, nos dépendances sont toujours disponibles. Mais c'est loin d'être parfait. 
D'abord, c'est de la responsabilité de l'utilisateur de la bibliothèque d'utiliser un proxy ou pas. 
Ensuite, on a toujours un souci lorsque notre source de vérité change d'adresse. Et c'est toujours aussi moche qu'avant :sweat:


## Replace

Dans le fichier `go.mod`, on peut utiliser la directive `replace` pour spécifiquement remplacer la source d'une lib par une autre. 
Cela est avant tout utilisé pour pouvoir tester ou utiliser une version différente, mais on peut forcer l'utilisation d'un miroir de cette façon.

```go
// go.mod
replace github.com/ztec/poulpe v0.3.1 => git2.riper.fr/ztec/poulpe v0.3.1
```
C'est pratique, mais pas vraiment sur le long terme. Je me vois mal le faire pour toutes les bibliothèques chargées par mes projets. 
Ça va vite devenir chiant. Et encore, cela reste toujours la responsabilité de l'utilisateur de la bibliothèque de le faire. 
De plus, c'est encore plus moche qu'avant :joy:

## Instead of

Une autre solution consiste à changer de manière globale l'emplacement des bibliothèques. 
À la manière de `replace`, on peut configurer dans `~/.gitconfig` des miroirs ou des sources alternatives. 
On peut le faire carrément pour tout un domaine, comme notre cible Github.com. 
C'est principalement utilisé pour changer le protocole, pour des raisons d'identification, mais cela peut être détourné.

```text
[url "ssh://git@github.com/"]
	insteadOf = https://github.com/
```

ou

```text
[url "https://git2.riper.fr/ztec"]
	insteadOf = https://github.com/ztec
```

C'est utile, mais pose les mêmes problèmes que la solution du `replace`. 

## Nom personalisé

Si on y réfléchit bien, la seule chose que nous pouvons vraiment posséder sur internet, c'est un nom de domaine, et ce qu'il y a derrière.
Glolang permet de rediriger n'importe quelle URL vers un paquet et c'est vraiment facile à faire.

Par exemple, j'ai changé le nom de mon paquet de `git2.riper.fr/ztec/poulpe` en `poulpe.ztec.fr`.

```go
// go.mod
module poulpe.ztec.fr
```

Simplement changer le nom dans le `go.mod` suffit pour le projet lui-même. Mais dès que vous voulez l'importer dans un autre projet,
il faut ajouter une autre ligne pour que Go puisse trouver votre bibliothèque.

Pour que le nouveau nom fonctionne pour tout le monde, il suffit simplement d'ajouter une balise meta dans la page retournée par l'URL du paquet.
Dans l'exemple, cette page est `https://poulpe.ztec.fr`.


```html
 <meta name=go-import content="poulpe.ztec.fr git https://git2.riper.fr/ztec/poulpe.git">
```

Lors d'un `go get`, Go regardera cette page et cherchera les balises `meta` et suivra les instructions qui y sont incluses.

## Quelques bénéfices au nom personalisé

En utilisant un nom personnalisé qui utilise votre domaine, comme dans l'exemple précédent, vous devenez maître de votre paquet.
Vous avez la liberté de changer l'adresse du dépôt à loisir, sans avoir à en changer le nom.

En plus, Github n'est plus "nécessaire" ni même mentionné lors de l'utilisation de votre bibliothèque.
Vous pouvez toujours l'utiliser pour votre dépôt, mais vous ne le criez plus sur tous les toits et c'est un avantage.

En plus de reprendre le contrôle de votre paquet, vous avez réduit la visibilité de Github et ce n'est pas rien.

Merci infiniment de m'avoir lu,\
[Bisoux](/page/bisoux) :kissing:

---
Quelques resources pour aller plus loin :
 - [when-should-i-use-the-replace-directive](https://github.com/golang/go/wiki/Modules#when-should-i-use-the-replace-directive)
 - [are-there-always-on-module-repositories-and-enterprise-proxies](https://github.com/golang/go/wiki/Modules#are-there-always-on-module-repositories-and-enterprise-proxies)
 - [how-to-use-a-private-go-module-in-your-own-project](https://www.digitalocean.com/community/tutorials/how-to-use-a-private-go-module-in-your-own-project)
 - [private-module-repo-auth](https://go.dev/ref/mod#private-module-repo-auth)
 - https://pkg.go.dev/rsc.io/go-import-redirector
 - [Remote_import_paths](https://pkg.go.dev/cmd/go#hdr-Remote_import_paths)
