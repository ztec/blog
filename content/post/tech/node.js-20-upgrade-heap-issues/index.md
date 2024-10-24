---
title: "Mise à jour Node.js 20 : une aventure inattendue, quand Kubernetes joue avec ma HEAP"
date: 2024-09-18T07:00:00+02:00
slug: "node.js-20-aventure-inattendue-kubernetes"
images: [2024/post/node.js-20-aventure-inattendue-kubernetes/img/deploy-2-system.png]
description: "Embarquez pour le voyage d'une mise à jour de Node.js, où les bonnes pratiques de l'univers Kubernetes ont eu des conséquences inattendues sur la mémoire HEAP."
tags: ["node.js", "tech", "kubernetes", "IA-helped"]
promotions:
    twitter: https://x.com/Ztec6/status/1836344503222849741
    mastodon: https://mamot.fr/@ztec/113157970545202111
---

Cet été, j'ai mis à jour un projet de Node.js 18 à Node.js 20. Le code n'était pas si vieux et je ne m'attendais pas à avoir des problèmes.
Mais comme à chaque mise à jour de Node.js, des comportements inattendus sont arrivé.<!--more-->

## Pourquoi mettre à jour ?

C'est évidemment une bonne pratique pour garder le projet à jour. Avoir trop de retard, 
c'est prendre le risque d'avoir plus de travail plus tard avec un calendrier imposé.
J'aurais pu attendre encore, mais j'ai profité du creu de l'été 
Node.js 18 est actuellement en "MAINTENANCE". Cela signifie qu'il y a des correctifs de sécurité, mais plus de nouvelles fonctionnalités. 
La phase de maintenance est prévue de se terminer l'année prochaine en juin.

Node.js 20 est la version LTS actuelle disponible. Elle est en développement actif et passera en phase de maintenance l'année prochaine.

{{< illustration src="img/nodejs-roadmap.png"
name="Roadmap des versions de Node.js"
alt="Toutes les versions de Node.js de 16 à 24 avec les dates pour chacune des phases : Current, Active, Maintenance"
resize="no" >}}

Peu après la sortie de la version LTS suivante (Node.js 22), une migration sera à l'ordre du jour avec peut-être un autre article si tout se passe mal !

## Comment ?

Cette partie est assez simple. Changer quelques valeurs dans le fichier "package.json", puis exécuter `npm install` comme d'habitude.

{{< illustration src="img/diff-package.json.png"
name="Diff du fichier package.json"
alt="L'engine Node est mis à jour à >=20.15.1 et npm à >= 10.7.0"
resize="no" >}}

Toutes les dépendances sont gérées par le bot [renovate](https://github.com/renovatebot/renovate). 
Par conséquent, le "package.json" ne contient que des versions exactes.

La version choisie de Node est la 20.15.1, car c'est la dernière version disponible lors de la mise à jour.
Toute mise à jour mineure future se fera automatiquement sans rien changer dans le fichier "package.json". 
Les images Docker sont construites régulièrement et ciblent la dernière version de Node.js 20 à la manière d'une "[rolling release](https://fr.wikipedia.org/wiki/Rolling_release)".

{{< illustration src="img/diff-dockerfile.png"
name="Diff du fichier Dockerfile"
alt="Diff du Dockerfile changeant le `FROM` d'une image node-18 à node-20, toutes deux maintenues en interne"
resize="no" >}}
## Déploiement et premiers résultats

Ce projet est critique, le déploiement est simple, rapide, et se fait généralement de manière sereine. 
Comme il s'agit d'une mise à jour potentiellement impactante, j'y ai prêté plus d'attention que d'habitude.

### Vitals du projet
Le tableau de bord principal que je regarde pendant un déploiement affiche les vitales du projet. 
Il contient toutes les métriques requises pour savoir en un coup d'œil si le service est en bonne santé ou non. 
Je ne rentrerai pas dans les détails pour des raisons de confidentialité, mais je peux vous montrer 
l'objectif de temps de réponse du projet :

{{< illustration src="img/deploy-1-project-goal.png"
name="Objectifs de temps de réponse"
alt="Graphique montrant le pourcentage de requêtes avec un temps de réponse inférieur à 100ms, 50ms, 10ms respectivement autour de 97%, 90%, et 45%"
resize="no" >}}

La ligne verticale violette est positionnée approximativement quand le déploiement a eu lieu, et comme elle n'est pas 
présente systématiquement, j'ai ajouté une flèche rouge sur tous les graphiques pour rendre ça plus clair.
Nous pouvons voir que le temps de réponse a augmenté. 
Le graphique montre le pourcentage de réponses qui correspondent à l'un des trois objectifs de temps de réponse que nous suivons. 
Les requêtes plus rapides que 100ms sont passées de 96,8% à 96,1%. C'est la loose ici.

Bon, on est d'accord que perdre environ 1 % est largement acceptable, mais cela montre qu'il s'est passé quelque chose.

Si nous regardons le temps de réponse moyen, nous pouvons voir plus nettement l'augmentation
qui est passée d'environ 23ms à 28ms.

{{< illustration src="img/deploy-1-project-response-time.png"
name="Temps de réponse moyen"
alt="Graphique montrant le temps de réponse moyen oscillant entre 22ms et 25ms"
resize="no" >}}

J'ai regardé les autres métriques, graphiques et logs et considéré le projet comme stable et en bonne santé malgré ces variations.
Il était maintenant temps de creuser pour comprendre ce qui s'est passé. 
Il n'y a aucune menace immédiate pour la stabilité du service et les variations de temps de réponse 
sont parfaitement acceptables et ne grève pas le [budget](https://www.atlassian.com/fr/incident-management/kpis/error-budget).
Je vais donc pouvoir prendre mon temps pour creuser, autrement, un rollback aurait été de rigueur.

### Vitales système
Le projet tourne dans un cluster Kubernetes et j'ai accès aux métriques de base, à savoir l'utilisation CPU et RAM des pods. 
Pour ceux qui ne sont pas familiers avec Kubernetes, considérez simplement un pod comme un processus Node.js 
démarré à l'intérieur d'un conteneur Docker.

#### Augmentation du CPU
Après le déploiement, je remarque une augmentation de l'utilisation du CPU, passant de 24% à 30% de la réservation. C'est la loose ici aussi.

{{< illustration src="img/deploy-1-CPU.png"
name="Graphique de l'utilisation CPU"
alt="Le CPU est passé de 24% à 30%"
resize="no" >}}

> Dans Kubernetes, nous définissons des réservations CPU et RAM. C'est une bonne pratique de préciser au cluster combien de ressources 
> les pods auront besoin. Par exemple, nous pouvons dire qu'un processus Node.js peut utiliser jusqu'à 2 CPUs. 
> Le graphique montre ensuite combien de ces 2 CPUs sont utilisés par rapport à la réservation. 
> La même chose s'applique à la RAM. 
> Bien sûr, le graphique montre les valeurs pour l'ensemble du cluster, pas seulement un pod.
>   
>  ```yaml
>  limits:
>    memory: 512Mi
>  requests:
>    memory: 512Mi
>    cpu: 2
>  ```
> Un exemple de configuration pour un pod. Cela signifie que le pod aura 2 CPUs et 512Mi de RAM à sa disposition.

#### Diminution de la consommation de mémoire
L'utilisation de la mémoire a diminué. C'est une victoire ici !

{{< illustration src="img/deploy-1-RAM.png"
name="Graphique de l'utilisation de la RAM"
alt="La RAM est passée de 75% à 55%"
resize="no" >}}
Ce projet perd toujours du poids après chaque déploiement. C'est normal, mais il le récupère après un certain temps. 
Il faut quelques heures pour que ça se stabilise. Cependant, cette fois-ci, la diminution est plus importante que d'habitude et,
à première vue, probablement là pour rester.

### Vitals Node.js
Coté Node.js, la première métrique qui m'intéresse, c'est l'[Event Loop Utilization (ELU)](https://nodesource.com/blog/event-loop-utilization-nodejs/).
Cette métrique est essentielle pour connaître la santé d'un processus Node.js.

Elle montre combien de temps le processus passe à travailler, combien de temps l'[event-loop](https://nodejs.org/en/learn/asynchronous-work/event-loop-timers-and-nexttick) est utilisé. 
Environ 0 % pour un process en attente, et 100 % pour une utilisation maximale de l'event-loop. 

{{< illustration src="img/deploy-1-elu.png"
name="Utilisation de l'Event Loop"
alt="L'ELU est passé de 17% à 20% en moyenne"
resize="no" >}}

On voit une légère augmentation après le déploiement, passant de 17% à 20% en moyenne. 
C'est la loose ici ! 

Ce n'est pas vraiment surprenant, car nous avons déjà vu que l'utilisation du CPU a augmenté. 
Mais on peut voir que cela a un impact sur le code JavaScript en cours d'exécution. 
Cela peut aussi expliquer l'augmentation du temps de réponse.

Après cela, je regarde la HEAP et les statistiques du Garbage Collector.

{{< illustration src="img/deploy-1-HEAP-GC.png"
name="Graphiques de toutes les espaces HEAP et des statistiques du Garbage Collector"
alt="Graphiques montrant tous les espaces HEAP et les statistiques du Garbage Collector"
resize="no" >}}

La HEAP s'allège, mais surtout, quelque chose se passe avec le Garbage Collector.
Sa déclinaison "minor" tourne beaucoup plus souvent et prend plus de temps.

Sans entrer dans les détails, le [minor GC](https://v8.dev/blog/trash-talk#minor-gc) est un processus qui cible les objets nouvellement créés dans la HEAP. 
Il y en a un autre (le Major GC) qui cible tous les objets "anciens".

Le minor GC est un processus rapide qui est prévu pour s'exécuter souvent. Il est normal de le voir appelé fréquemment. 
Mais ici, quelque chose a changé. On est passé de quelques centaines d'appels à des milliers. 
Même si c'est un processus rapide, il a consommé près de 4 secondes de temps CPU sur l'ensemble du cluster. 
En comparaison, nous consommions moins d'une seconde avant le déploiement.

Cette augmentation permet facilement d'expliquer celle de l'utilisation CPU et une partie de l'ELU, 
et donc du temps de réponse. 

J'ai peut-être trouvé mon coupable.

## Problème identifié, et maintenant ?

Ok, il se passe quelque chose de louche avec le Garbage Collector. Mais quoi ?

Si on regarde plus en détail la HEAP, on peut voir quelques changements notables après le déploiement :

{{< illustration
src="img/deploy-1-HEAP-NEW.png"
name="Taille des espaces HEAP: map, new, shared"
alt="Graphique de la HEAP montrant les espaces map, new, et shared"
resize="no" >}}

L'espace **map** a disparu et les espaces **shared** sont apparus. Mais surtout, l'espace **new** est passé de ~33MB à ~8MB.

Vous souvenez-vous de ce que j'ai écrit quelques lignes plus tôt ?

> Le Minor GC cible les objets nouvellement créés dans la HEAP.

Est-ce la raison pour laquelle le GC tourne maintenant si souvent ? Sûrement qu'un espace plus petit signifie plus de GC. 
Quand il est plein, le GC doit s'exécuter pour libérer de l'espace. 
S'il est plus petit, il sera plein plus rapidement. 
Il s'exécutera donc plus fréquemment.

### Pourquoi l'espace "new" est-il plus petit ?

Il n'y a pas de configuration de la HEAP qui cible l'espace **new** dans le projet.
Cela signifie que Node.js lui-même a probablement changé entre la version 18 et 20. 
Cependant, un espace HEAP est configuré : l'espace **old**. 
Nous lançons le serveur avec la commande suivante :

```bash
node --max-old-space-size=300 dist/server.js
```

Je n'avais aucune idée si cela impacte l'espace "new" également. À partir de là, j'ai commencé à y chercher des références dans les 
notes de version de Node.js. Au début, je n'ai rien trouvé d'utile, mais après un moment, j'ai fait le lien entre l'espace "new" et l'espace "semi". 
Le moteur V8 sous le capot de Node.js utilise cette terminologie au lieu de l'espace "new". 
Et bien sûr, j'ai trouvé un changement dans les notes de version de Node.js 19 : [https://github.com/nodejs/node/pull/44436](https://github.com/nodejs/node/pull/44436)

Le paramètre `--max-semi-space-size` a été ajouté car il a lui-même été ajouté au moteur V8. De fil en aiguille, j'ai finalement trouvé 
ces changements dans le moteur V8 : [https://chromium-review.googlesource.com/c/v8/v8/+/1631593](https://chromium-review.googlesource.com/c/v8/v8/+/1631593) et https://chromium-review.googlesource.com/c/v8/v8/+/4384482

Ces changements modifient en fait la façon dont la taille de l'espace "semi" est calculée. 
Je ne suis pas un expert en C, mais en lisant simplement les commentaires et certaines parties du code, 
on peut rapidement voir que la taille de l'espace "new" a changé. 
La nouvelle taille est maintenant calculée à partir de diverses autres valeurs. 
Je ne suis malheureusement pas capable de comprendre exactement comment elle est calculée car mon C++ est un peu rouillé et V8 n'est pas un projet simple.
Je ne peux que faire des hypothèses à ce stade de l'enquête, et l'une d'elles est que la taille de l'espace "new" est calculée par rapport à celle de l'espace "old".

Le changement a été introduit dans V8 10.6 et fait maintenant partie de Node.js 20 qui utilise V8 11.3. 
Pour référence, Node.js 18 utilisait V8 10.2. Cela signifie qu'en passant de Node.js 18 à 20, nous sommes également passés de V8 10.2 à 11.3.

### Une solution ?

La solution la plus simple est de revenir à la taille de l'espace "new" précédente. 
Je vais donc essayer de le faire en ajoutant un paramètre à la commande de démarrage du serveur. 
Ça tombe bien, un nouveau paramètre a été introduit pour spécifier la taille de l'espace "new" : `--max-semi-space-size`.

Je teste donc avec ça :

```bash 
node --max-semi-space-size=16 --max-old-space-size=300 dist/server.js
```

Le 16 vient de la [documentation elle-même](https://github.com/nodejs/node/blob/86415e4688f466c67878d525db4ebc545492bcd7/doc/api/cli.md?plain=1#L3363).

    --max-semi-space-size=SIZE (in megabytes)
    
    Sets the maximum [semi-space][] size for V8's [scavenge garbage collector][] in
    MiB (megabytes).
    Increasing the max size of a semi-space may improve throughput for Node.js at
    the cost of more memory consumption.
    [...]    
    The default value is 16 MiB for 64-bit systems and 8 MiB for 32-bit systems. 
    [...]
    
    ----

    --max-semi-space-size=SIZE (in megabytes)
    
    Définit la taille maximum pour l'espace semi dans V8 en MiB (mégaoctets).  
    Augmenter la taille maximale de l'espace semi peut améliorer le débit de Node.js au 
    détriment de la consommation mémoire.  
    [...]  
    La valeur par défaut est de 16 MiB pour les systèmes 64 bits et 8 MiB pour les systèmes 32 bits.  
    [...]

Je déploie ce changement simple et regarde les métriques.

{{< illustration src="img/deploy-2-project.png"
name="Objectifs de temps de réponse & temps de réponse moyen"
alt="Graphique montrant le pourcentage de requêtes avec un temps de réponse inférieur à 100ms, 50ms, 10ms et le temps de réponse moyen"
resize="no" >}}

Le temps de réponse semble être revenu à la normale. C'est une victoire !

{{< illustration src="img/deploy-2-system.png"
name="Utilisation CPU & RAM"
alt="Graphique montrant l'utilisation CPU et RAM revenant à des valeurs normales"
resize="no" >}}

L'utilisation CPU est également revenue à la normale, et l'utilisation RAM est toujours inférieure aux valeurs précédentes. 
C'est une double victoire !

{{< illustration src="img/deploy-2-nodejs.png"
name="Métriques Node.js incluant ELU, HEAP et GC"
alt="Graphique montrant l'ELU, HEAP et GC revenant à des valeurs normales"
resize="no" >}}

Enfin, on peut voir que le GC est revenu à un comportement normal. De plus, l'espace "new" est maintenant revenu à sa valeur d'origine. 
Cela confirme l'hypothèse que la taille de l'espace "new" était le problème.

## Il s'est passé quoi ?

À ce stade, le problème est résolu en production. Mais je veux comprendre ce qui a exactement causé la réduction de l'espace "new" comme ça. 
Mon hypothèse est que la `max-semi-space-size` est maintenant calculée par rapport à la taille de l'espace "old".
Comme nous spécifions un `--max-old-space-size` de 300 MB, qui est une valeur relativement faible pour Node.js, 
il n'est pas surprenant que cela ait un impact significatif sur la taille de l'espace "new" et l'ait fait rétrécir autant.

C'est le moment de construire un projet de laboratoire pour tester et confirmer cette hypothèse.

### Le lab

J'ai trouvé un script de consommation de HEAP basique en ligne et j'ai utilisé le module standard `v8` pour obtenir les statistiques HEAP.

Voici le script résultant :

```javascript
const v8 = require('v8');

// Fonction basique volée quelque part sur Internet et modifiée pour allouer
// beaucoup de nouveaux objets. Un peu barbare, je sais, mais ça fait le job.
function allocateMemory(size) {
    // Simule l'allocation de données
    const numbers = size / 8;
    const arr = [];
    arr.length = numbers;
    for (let i = 0; i < numbers; i++) {
        arr[i] = {"test": Math.random()};
        arr[i][`${Math.random()}`] = Math.random();
    }
    return arr;
}
// On alloue de la mémoire pour déclencher le garbage collector
// et forcer la HEAP à grandir, y compris donc l'espace "new"
allocateMemory(1000000)
const heapSpaces = v8.getHeapSpaceStatistics()
console.log(
    // On filtre l'espace "new" et on affiche sa taille en MB pour plus de commodité
    heapSpaces.filter(item => item.space_name === 'new_space')[0].space_size 
    / 1024 / 1024
);
```

En exécutant ce script, la sortie sera un nombre représentant la taille de l'espace "new_space" en MB. 
Avant de le renvoyer, je m'assure que cet espace a été agrandi à sa valeur maximale en allouant des objets en mémoire.


```bash
$ node test.js
32
```

Maintenant, exécutons ce script avec `--max-old-space-size` défini à 300 Mo en utilisant Node 18, puis Node 20.

```bash
$ nvm use 18
Now using node v18.20.4 (npm v10.7.0)
$ node --max-old-space-size=300 test.js
32
$ nvm use 20
Now using node v20.15.1 (npm v10.7.0)
$ node --max-old-space-size=300 test.js
32
```

Les deux versions donnent le même résultat. L'espace "new_space" est de la même taille pour les deux versions. J'avais clairement tort.

Bien sûr, faire la même chose sans le `--max-old-space-size` donne exactement le même résultat.

{{< illustration
src="img/doctor-what.png"
name="Moi regardant les résultats"
alt="Moi (représenté par William Hartnell) regardant les résultats avec étonnement" >}}

Qu'est-ce qui se passe ? Pourquoi mon projet se comporte-t-il différemment ?

Après quelques recherches supplémentaires dans le code V8 et, surtout, un indice de mon collègue {{<source-link "/sources/zibok">}}, 
j'ai peut-être une nouvelle piste liée à la réservation de mémoire dans la configuration Kubernetes.

L'hypothèse est maintenant la suivante : la taille de "new_space" est calculée en relation avec la réservation de mémoire du pod.

> Sans entrer dans les détails, la réservation de mémoire et de CPU dans Kubernetes se fait à travers le noyau (Kernel). Cela signifie que
> la réservation est en réalité appliquée par le noyau lui-même. Elle est imposée directement au processus s'exécutant à l'intérieur du pod
> via le [cgroup](https://fr.wikipedia.org/wiki/Cgroups). En consequence, le processus lui-même peut être "conscient" de la limite et peut s'adapter à celle-ci.

Je peux tester cela dans un cluster Kubernetes, mais il y a peut-être une manière plus simple de tester cette hypothèse. 
Bien sûr, Docker permet également de définir une réservation de mémoire via le paramètre `--memory`. Plus d'informations [ici](https://docs.docker.com/config/containers/resource_constraints/).

Premièrement, sans réservation de mémoire :

```bash
$ docker run -ti --rm -v ./:/ node:18 node /test.js
32
$ docker run -ti --rm -v ./:/ node:20 node /test.js
32
```
Comme prévu, cela donne exactement le même résultat que précédemment.

Maintenant, avec des limites :

```bash
$ docker run --memory=512m -ti --rm -v ./:/ node:18 node /test.js
32
$ docker run --memory=512m -ti --rm -v ./:/ node:20 node /test.js
2
```

Cette fois, nous avons un résultat différent. 
La taille de "new_space" est maintenant de 2 Mo.

Cela confirme l'hypothèse que la réservation de mémoire est utilisée pour calculer la taille de "new_space".

{{< illustration src="img/doctor-disco.gif"
name="Moi dansant sur les résultats"
alt="Moi (représenté par Peter Capaldi) dansant sur les résultats" >}}

J'ai maintenant mon coupable. 
La réservation de mémoire dans la configuration Kubernetes est la raison pour laquelle la taille de "new_space" a tant rétréci.

## Conclusion

L'update vers Node 20 est une victoire. La consommation mémoire globale est significativement plus basse qu'avant. 
À part un moment où la taille de "new_space" était trop petite, tout a fonctionné aussi bien qu'avant, voire mieux même.

Utiliser Node.js dans un environnement Kubernetes, et plus largement dans un scénario conteneurisé, 
nécessite de prendre en compte la réservation de mémoire et de CPU.
Il faut définir des limites pour éviter qu'un processus ne consomme toutes les ressources disponibles.
Cependant, les définir à des valeurs très basses nécessite une attention particulière pour s'assurer 
que le processus s'adapte correctement aux limites.

Aujourd'hui, nous avons vu que définir des limites de RAM sur un processus Node.js impacte également combien il se permet de consommer. 
En production avec des services à forte utilisation ou des appels fréquents, cela peut impacter les performances et la latence. 
Si je n'avais pas surveillé les métriques, nous aurions diminué notre objectif de temps de réponse de près de 1 %. 
Une honte, je sais !

Peut-être que j'écrirai un article sur les impacts des limites CPU sur les processus Node.js. 
Cela a aussi eu des effets surprenants quand j'ai testé il y a quelques années.

Le ~~mot~~ paragraph de la fin est :
> Dans Node.js, l'espace HEAP est maintenant (depuis Node 19) dimensionné en fonction des limites de mémoire du processus (entre autres).
> 
> Dans un contexte Kubernetes/Containers, où la pratique habituelle est de définir des limites de mémoire, 
> il faut y prêter suffisamment attention pour ne pas impacter les performances de manière inattendue. 
> Le paramètre --max-semi-space-size est à garder en tête dans ce cas.

#### Mise à jour 24th October 2024
[Joe Bowbeer](https://github.com/joebowbeer) a ouvert une [issue](https://github.com/nodejs/node/issues/55487) et proposé une [PR](https://github.com/nodejs/node/pull/55495) directement sur le projet Node.js pour clarifier le comportement du "semi-space".
PR toujours en attente de review à ce jour.

Merci infiniment de m'avoir lu,\
[Bisoux](/page/bisoux) :kissing: