---
title: "Une commande m'a fait gagner 1.2To d'espace libre"
date: 2022-11-25T11:00:00+02:00
slug: "tune2fs-espace-reserve"
tags: ["linux", "ext4", "tech"]
---


## Trop long, j'ai pas le temps

Les partitions Ext4 [réservent 5%](https://listman.redhat.com/archives/ext3-users/2009-January/msg00026.html) du volume pour garantir qu'il y a toujours un peu de place libre.
J'ai reconfiguré cette reservation de 5% à 0.05% car sur un volume de plusieurs téra je préfère l'utiliser pour stoker des vraies données. 

Pour far ça j'ai executer la commande suivante : 

```bash
sudo tune2fs -m 0.05 /dev/vda
```

## J'ai un NAS

J'ai un NAS hcez moi, et je le gère à la main. Ça veut dire que je n'utilise ni TrueNas et que c'est pas un NAS tout fait comme un Synology par exemple.
C'est un ordinateur avec une distribution basée sur Debian (Proxmox en vrais), avec des disques en RAD matériel dessus. 

J'ai un gros volume [LVM](https://fr.wikipedia.org/wiki/Gestion_par_volumes_logiques) avec une partition ext4 ou je mets tous mes fichiers.
Je le maintiens depuis 3-4 ans. Il grossit a chaque fois que je rajoute des disques. De quelques téra il fait maintenant 24To. 

J'ai mis du monitoring en place pour surveiller son utilisation. Vous imaginez bien que tout espace libre, ne le reste pas bien longtemps. 

{{< illustration src="img/fullCargoGraph.png"  name="Cargo est plein"   alt="Une jauge qui montre que le volume CARGO est plein à 97.2%" resize="no" >}}

Je n'ai pas la main assez verte pour faire pousser un [arbre à simflouz](https://fr.wikipedia.org/wiki/Simflouz), du coup je ne peux pas rajouter des disques infiniment.

{{< illustration src="img/MoneyTree.png"  name="Arbre a simflouz du jeu Sims 2"   alt="Arbre a simflouz du jeu Sims 2" resize="no" >}}

Je fais donc du ménage de temps en temps. Généralement, je supprime plein de truc. Majoritairement tout ce qui n'est plus utile comme 
des films ou des jeux de donnée de projets abandonnée. Je parviens souvent à libérer quelques térabytes. 

## Netoyage de printemps
Aujourd'hui, c'était nettoyage de printemps ... en automne. Après avoir fini, je passe vite fait dans la corbeille pour
vider définitivement quelques fichiers qui n'attendait que ça.
À l'occasion, je fais un `df` sur le serveur pour regarder tout l'espace que j'ai gagné et enfin pouvoir me féliciter des économies réalisées. 
Cependant, en regardant les données de plus près, je suis surpris. 

{{< illustration src="img/dfBefore.png"  name="df avant"   alt="Résultats de la commande `df` montrant taille=24T, utilisé=20T, disponible=2.4T utilisé=90%" resize="no" >}}

### Qui m'a piquer ces 1.2To ?

Bon, je lance une calculatrice fiable (mon cerveau ne l'est vraiment pas), et oui 24-20 = 4, pas 2.4.
Je sait bien que tout système de fichier a besoin d'un peu de place pour stoker les journaux et quelques données techniques, mais
1.6To me semble un peu excessif au regard du besoin. 

Après un [appel à internet](https://www.youtube.com/watch?v=-SudFQb9lsY), je [trouve](https://www.linuxquestions.org/questions/linux-general-1/reserved-space-on-ext4-database-file-system-4175564363/) 
que le système de fichier `ext4` réserve par défaut 5% de la taille totale d'un volume. 
Cette reservation est lá pour s'assurer qu'il y ait toujours un peu de place sur le volume, meme quand celui-ci est considéré plein.

C'est apparent de la plus haute importance, notamment pour les partitions système. Car plus d'espace libre = pas de shell. 
Croyez-moi, je suis assez vieux pour avoir bossé sur des systèmes suffisamment anciens pour ne pas avoir ce genre de protections.
C'était pas très fun de devoir trouver un moyen de s'y connecter, surtout quand aucun accès physique n'était possible.

Un autre bonus de cette réservation, c'est d'aider dans la lute contre la [fragmentation](https://fr.wikipedia.org/wiki/Fragmentation_(informatique)).
Comme j'utilise des disques durs et non des SSD, la fragmentation reste importante à garder en tête.
Cependent, j'ai majoritairement du contenu froid, c'est-à-dire qu'il bouge pas beaucoup. Bien que certain fichier 
soit plus vivant, je pense pas que ça soit un gros soucis dans mon cas. 

### Rend les térabytes

Comme je n'ai finalement pas de vrai usage de cette espace réservé, j'ai intérêt à m'en débarrasser ou à le réduire au maximum.
C'est donc ce que j'ai fait avec la commande suivante

```bash
sudo tune2fs -m 0.05 /dev/vda
```
TaDa ! 
{{< illustration src="img/dfAfter.png"  name="df après"   alt="command `sudo tune2fs -m 0.05 /dev/vda` et le résultat de la commande `df` montrant taille=24T, utilisé=20T, disponible=3.6T utilisé=86%" resize="no" >}}
{{< illustration src="img/notSoFullCargo.png"  name="Cargo n'est plus plein" alt="Une jauge qui montre que le volume CARGO est remplis à 85.1%" resize="no" >}}

## Conclusions

Je gère mon NAS à la main, et j'apprends en le faisant. Aujourd'hui j'ai appris des choses. Objectif attain.
aussi: 
 - Maintenant, il y a des securitée pour éviter de se trouver bloqué a l'extérieur de son serveur.
 - Ext4 réserve 5% d'un volume et c'est pas forcément utile dans tous les cas, surtout si la partition n'est finalement pas utiliser pour monté la racine ou un dossier système. 
 - [e4defrag](https://manpages.ubuntu.com/manpages/bionic/man8/e4defrag.8.html) existe, et peu être utliser pour calculer la framentation et faire de la défragmentation, mais c'est très très très long.

Merci infiniment de m'avoir lu,\
[Bisoux](/page/bisoux) :kissing:
