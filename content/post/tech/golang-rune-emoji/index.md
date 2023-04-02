---
title: "🐙 un moteur de recherche d'émojis"
date: 2023-04-02T15:00:00+02:00
slug: "moteur-de-recherche-emojis"
tags: ["tech", "go", "emoji", "IA-helped"]
---

Pour un de mes projets, j'ai dû gérer des émojis. Le but était de créer un moteur de recherche d'émojis.
Je ne pars pas de rien, car je dois inclure le tout dans un de mes programmes qui tourne déjà, et c'est en Go. 
Regardons ensemble comment construire un petit moteur de recherche en go. 

Pour les plus impatients, l'ensemble des example de code de cet article sont ici : [git2.riper.fr/ztec/emoji-search-engine-go](https://git2.riper.fr/ztec/emoji-search-engine-go)

## :boar: Émojis! Attrapez les tous!

En premier lieu, il m'a fallu trouver la liste de tous les émojis qui existe. Le site de l'Unicode
en met une à disposition

https://unicode.org/Public/emoji/15.0/emoji-test.txt

Le fichier ressemble a ça

```
[…]
# group: Smileys & Emotion

# subgroup: face-smiling
1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face
1F603                                                  ; fully-qualified     # 😃 E0.6 grinning face with big eyes
1F604                                                  ; fully-qualified     # 😄 E0.6 grinning face with smiling eyes
1F601                                                  ; fully-qualified     # 😁 E0.6 beaming face with smiling eyes
1F606                                                  ; fully-qualified     # 😆 E0.6 grinning squinting face
1F605                                                  ; fully-qualified     # 😅 E0.6 grinning face with sweat
[…]
```

On y trouve le code Unicode, l'émoji lui-même, et une description. Le fichier est prévu pour les machine, il devrais donc
être facile à parser.

Avant de commencer dans cette direction tête baissée, regardons ce que la communauté a deja fait sur le sujet.

J'ai trouvé:
 - [github.com/enescakir/emoji](https://github.com/enescakir/emoji), mis à jour en 2020.
 - [AkinAD/emoji](https://github.com/AkinAD/emoji), mis à jour en 2022 (un fork du premier).
 - [github.com/kenshaw/emoji](https://github.com/kenshaw/emoji), mis à jour en 2021.

En regardant dans le code de ces projets j'ai trouver un truc très intéressant :
https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json

Le fichier, qui est mis a jour régulièrement, est parfait et peu être encore plus facilement parser. C'est du JSON.
En plus de ça, il contient quelques informations supplémentaires comme les alias.

This is the way, on va parser ce fichier directement!

```go
package pouet

import (
	"encoding/json"
	"github.com/go-zoox/fetch"
)

type EmojiDescription struct {
	Emoji          string   `json:"emoji"`
	Description    string   `json:"description"`
	Category       string   `json:"category"`
	Aliases        []string `json:"aliases"`
	Tags           []string `json:"tags"`
	HasSkinTones   bool     `json:"skin_tones,omitempty"`
	UnicodeVersion string   `json:"unicode_version"`
}

type GithubDescriptionResponse []EmojiDescription

func fetchEmojiFromGithub() (results []EmojiDescription, err error) {
	response, err := fetch.Get("https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json")
	if err != nil {
		return
	}
	err = json.Unmarshal(response.Body, &results)
	return
}
```

J'ai utilisé `github.com/go-zoox/fetch`, pour récupérer le fichier, car je suis paresseux.

## :zebra: Émoji, Scannez les tous! 

dans mon programme, j'utilise déjà [Bleve](https://blevesearch.com/) pour indexer d'autre truc. Je vais donc l'utiliser ici aussi.
L'opération est plutôt simple, car je n'ai pas à conserver de copie de l'index, juste une version en mémoire suffit.

```go
package pouet

import (
	"fmt"
	"github.com/blevesearch/bleve/v2"
	"github.com/sirupsen/logrus"
	"strconv"
	"strings"
)

var (
	index  bleve.Index
	emojis []EmojiDescription
)

func indexEmojis() error {
	// we create a new indexMapping. I used the default one that will index all fields of my EmojiDescription
	mapping := bleve.NewIndexMapping()
	// we create the index instance
	bleveIndex, err := bleve.NewMemOnly(mapping)
	if err != nil {
		return err
	}
	// we fetch the emoji from the internet. This can fail, and may be embedded for better performance
	e, err := fetchEmojiFromGithub()
	if err != nil {
		logrus.WithError(err).Error("Could fetch emoji list")
		return err
	}
	emojis = e
	for eNumber, eDescription := range emojis {
		// this will index each item one by one. No need to be quick here for me, I can wait few ms for the program to start
		err = bleveIndex.Index(fmt.Sprintf("%d", eNumber), eDescription)
		if err != nil {
			logrus.WithError(err).Error("Could not index an emoji")
		}
	}
	index = bleveIndex // we make the index available
}
```
Une fois que la fonction `indexEmojis` est appelée, j'ai un `index` pres a l'emploi pour chercher des émojis. Testons-le.

```go
package pouet

import (
	"fmt"
	"github.com/AkinAD/emoji"
	"github.com/blevesearch/bleve/v2"
	"github.com/sirupsen/logrus"
	"strconv"
	"strings"
)

var (
	index  bleve.Index
	emojis []EmojiDescription
)

func Search(q string) (results []EmojiDescription) {
	if index == nil {
		// no Index mean indexEmojies was not called yet or did not finished. No results (boot process)
		return
	}
	// we create a query as bleve expect.
	query := bleve.NewQueryStringQuery(q)
	// we define the search options and limit to 200 results. This should be enough.
	searchrequest := bleve.NewSearchRequestOptions(query, 200, 0, false)
	// we do the search itself. This is the longest. Approximately few hundreds of us 
	searchresults, err := index.Search(searchrequest)
	if err != nil {
		logrus.WithError(err).Error("Could not search for an emoji")
		return
	}
	
	// we return the results. I use the index to find my original object stored in `emojis` because it's simpler. Optimisation possible.
	for _, result := range searchresults.Hits {
		numIndex, _ := strconv.ParseInt(result.ID, 10, 64)
		results = append(results, emojis[numIndex])
	}
	return
}
```

J'ai choisi d'utiliser `NewQueryStringQuery` car il permet [pas mal d'options](https://blevesearch.com/docs/Query-String-Query/) lors de la recherche, directement via la chaine.
Comme ça je pourrais ajouter des modificateurs pour affiner mes recherches. J'utilise beaucoup ces options pour les autres trucs que j'indexe, ça ne sera peut-être pas si utile que ça sur des émojis, 
mais ça ne coute pas grand-chose alors je le garde quand même. 

> Détendez-vous et imaginez un clip musical de moi qui ajoute le code qeu vous avez vu dans mon programme et créant une superbe interface pour envoyer les recherche et voir les résultats


{{< photo-gallery >}}
{{< photo src="img/search-ok-grin.png"        name="Résultat de la recherche grin"            alt="Résultat de la recherche `grin` affichant l'émoji `grin` comme prévu" >}}
{{< photo src="img/search-ok-smile.png"       name="Résultat de la recherche smile"           alt="Résultat de la recherche `smile` affichant plusieurs émojis souriant" >}}
{{</photo-gallery>}}

## :bubble_tea: Recherche approximative (Fuzzy)

C'est cool, les résultats sont bons, mais il semblerait qu'il y ait des ratés.

{{< illustration src="img/search-ko-hug.png"        name="Résultat de la recherche hug"            alt="Résultat de la recherche `hug` qui n'affichent pas de résultats" >}}

Ici, je devrais avoir un émoji en résultat. c'est :hugs:!. Si j'ajoute le `s` à la requette le moteur le trouve, mais aps sans.
Essayons d'améliorer ça en acceptant des résultats approximatifs.

L'idée est de chercher les résultats proches de la recherche souhaité, meme s'ils on un ou deux character de différent.
Pour faire ça, on va utiliser un truc qui s'appelle la [Distance de Levenshtein](https://fr.wikipedia.org/wiki/Distance_de_Levenshtein).
C'est cool, car Bleve intègre ce mécanisme déjà. Malheureusement, je n'ai pas trouvé comment l'utiliser avec les `QueryStringQuery`, notamment pour ajouter
un niveau approximation par défaut. Je peux toujours ajouter un `~` après un mot pour l'activer sur celui-ci, mais ce n'est pas pratique.

C'est un petit projet perso, alors on va y aller en suivant la méthode [RACHE](https://www.la-rache.com/).
Si je n'ai pas de résultats avec la première méthode, je tente avec une recherche dédier.

```go
func Search(q string) (results []EmojiDescription) {
	if index == nil {
		// no Index mean indexEmojies was not called yet or did not finished. No results (boot process)
		return
	}
	// we create a query as bleve expect.
	query := bleve.NewQueryStringQuery(q)
	// we define the search options and limit to 200 results. This should be enough.
	searchrequest := bleve.NewSearchRequestOptions(query, 200, 0, false)
	// we do the search itself. This is the longest. Approximately few hundreds of us 
	searchresults, err := index.Search(searchrequest)
	if err != nil {
		logrus.WithError(err).Error("Could not search for an emoji")
		return
	}
	
	// If we have no results we try to do a basic fuzzy search
	if len(searchresults.Hits) == 0 {
		// this time, we create a fuzzy query. The rest is the same as before. CopyPasta style. 
		fuzzyQuery := bleve.NewFuzzyQuery(q)
		searchrequest := bleve.NewSearchRequestOptions(fuzzyQuery, 200, 0, false)
		searchresults, err = index.Search(searchrequest)
		if err != nil {
			logrus.WithError(err).Error("Could not search for emoji")
			return
		}
	}
	// we return the results. I use the index to find my original object stored in `emojis` because it's simpler. Optimisation possible.
	for _, result := range searchresults.Hits {
		numIndex, _ := strconv.ParseInt(result.ID, 10, 64)
		results = append(results, emojis[numIndex])
	}
	return
}
```
{{< illustration src="img/search-ok-hug.png"        name="Résultat de la recherche hug"            alt="Résultat de la recherche `hug` qui affiche maintenant plusieurs résultats dont l'emoji `hug`" >}}

C'est bon cette fois, j'ai bien mon émoji câlins. J'ai aussi quelques autres résultats, mais franchement ça va. Je ne m'attends pas à avoir 
mon résultat en premier. Du moment qu'il est visible sans descendre dans la page ça me va.

> note: j'aurais pu aussi utiliser une recherche par prefix, mais je ne cherche pas toujours en utilisant le début du nom des émoji donc je préfère la recherche fuzzy

## :purple_square: Les couleurs de peau

Si je cherche pour l'émoji `ok hand` je le trouve. Cependant, il n'y a que la version de base, la jaune.
J'aimerais bien aussi voir les variations quand il y en a.

{{< illustration src="img/search-ok-hand-no-black.png" name="Résultat de la recherche ok hand" alt="Résultat de la recherche `ok hand` n'affichant que des émoji jaune" >}}

> Détendez-vous une seconde encore, et imaginez qu'un narrateur fait irruption dans votre tête avec une voix profonde et raconte :
> "Zed ne le sait pas encore, mais inclure ces jolis émojis avec toutes les couleurs de peau sera une tâche difficile. Des heures passerons avant qu'il ne réussisse le challenge et qu'il comprenne enfin"

Avant de continuer, petites explications sur comment marche les émojis. Ce sont des caractères UTF-8. Ces caractères peuvent être combinés 
ensemble pour former ce qu'on appelle des [ligatures](https://fr.wikipedia.org/wiki/Ligature_(%C3%A9criture)).
Vous prenez deux codes UTF-8 caractère et vous les collez ensemble en un seul character. Sur votre écran, vous verrez alors un autre caractère
qui n'est aucun des deux premiers. Dans les textes, c'est utilisé pour les liaisons graphiques et pour rendre le texte lisible quand deux lettres simplement coller l'une à côté de l'autre le sont moins.
La beauté du concept, c'est que si votre police ou votre écran ne supporte pas ces ligatures, vous verrez toujours les deux premiers caractères. Cool non ?

La couleur de peau d'un émoji est géré avec des ligatures. Vous prenez un émojis, et y coller le caractère de la couleur de peau que vous voulez. Le résultat sera un nouvel émoji
avec le jaune remplacer par la couleur choisi. Bien sûr, il faut que la police de caractère le supporte, donc toutes les combinaisons ne sont pas possibles.

```
1F44C                                                  ; fully-qualified     # 👌 E0.6 OK hand
1F44C 1F3FB                                            ; fully-qualified     # 👌🏻 E1.0 OK hand: light skin tone
1F44C 1F3FC                                            ; fully-qualified     # 👌🏼 E1.0 OK hand: medium-light skin tone
1F44C 1F3FD                                            ; fully-qualified     # 👌🏽 E1.0 OK hand: medium skin tone
1F44C 1F3FE                                            ; fully-qualified     # 👌🏾 E1.0 OK hand: medium-dark skin tone
1F44C 1F3FF                                            ; fully-qualified     # 👌🏿 E1.0 OK hand: dark skin tone
```

La première colonne contient le code UTF-8 de chaque émojis. On voit bien que la première partie ne change pas. C'est le code de :ok_hand: .
Le second code est la couleur de peau. Nous avons donc la liste des couleurs de peau disponible. 


```go
	tones := map[string][]rune{
      "light skin tone" : []rune("\U0001F3FB"),
      "medium-light skin tone" : []rune("\U0001F3FC"),
      "medium skin tone" : []rune("\U0001F3FD"),
      "medium-dark skin tone" : []rune("\U0001F3FE"),
      "dark skin tone" : []rune("\U0001F3FF"),
	}
```

Dans les librairies dont j'ai parlé en début d'article, les émojis et leurs codes sont géré via des `string` et utilise la syntax spécifique de l'UTF-8 en go (`\Uxxxxxxxx`) . 
Golang possède cependant un type dédier a la manipulation de caractères UTF-8, la `rune`. J'ai décidé de l'utiliser. 
Malheureusement, il y a vraiment peu d'exemple en ligne qui utilise les runes, surtout avec des ligatures.
J'ai utilisé la representation en `string` ici pour que l'on voie bien le code et le lien entre les runes et le caractère.

Maintenant, on a besoin de créer un nouvel émojis pour chaque variation de couleur. Tous les émojis ne supporte pas ces variations.
Je pourrais parser le fichier original d'Unicode, mais je suis paresseux, vous savez. En plus, si vous avez fait attention avant,
le fichier qu'on parse déjà possède un champ qui donne cette information sous forme d'un `bool', il n'y a donc rien à faire. :tada:

```go
func enhanceEmojiListWithVariations(list []EmojiDescription) []EmojiDescription {
	tones := map[string][]rune{
        "light skin tone" : []rune("\U0001F3FB"),
        "medium-light skin tone" : []rune("\U0001F3FC"),
        "medium skin tone" : []rune("\U0001F3FD"),
        "medium-dark skin tone" : []rune("\U0001F3FE"),
        "dark skin tone" : []rune("\U0001F3FF"),
    }
	for _, originalEmoji := range list {
		// we only add variations for emoji that supports it
		if originalEmoji.HasSkinTones {
			// we do it for every skin tone
			for skinToneName, tone := range tones {
				// we make a copy of the emojiDescription
				currentEmojiWithSkinTone := originalEmoji
				
				// This is the important bit that took me hours to figure out
				// we convert the emoji in rune (string -> []rune). An emoji can already be composed of multiple sub UTF8 characters, therefore multiple runes.
				// we append to the list of runes the one for the skin tone.
				// finally, we convert that in string using the type conversion. Using fmt would result in printing all runes independently
				currentEmojiWithSkinTone.Emoji = string(append([]rune(currentEmojiWithSkinTone.Emoji), tone...))
				
				// we adapt the description and metadata to match the skin tone
				currentEmojiWithSkinTone.Description = fmt.Sprintf("%s %s", currentEmojiWithSkinTone.Description, skinToneName)
				aliases := []string{}
				for _, alias := range currentEmojiWithSkinTone.Aliases {
					// we update all aliases to include the skin tone
					aliases = append(aliases, fmt.Sprintf("%s_%s",alias,strings.ReplaceAll(strings.ReplaceAll(skinToneName,"-", "_")," ", "_")))
				}
				currentEmojiWithSkinTone.Aliases = aliases
                // I cleared the unicode version because some emoji with skin tone were added way after their original. I could parse the unicode list,
				// but I'm a loafer, so I did not.
				currentEmojiWithSkinTone.UnicodeVersion = "" 
				// we add the new emoji to the list
                list = append(list, currentEmojiWithSkinTone)
			}
		}
	}
	return list
}
```

La clé :key: ici, c'est cette ligne :
```go
currentEmojiWithSkinTone.Emoji = string(append([]rune(currentEmojiWithSkinTone.Emoji), tone...))
```
Je ne suis pas un expert Go, encore moins en UTF-8. J'ai donc surement raté un ou des trucs, mais après des heures essayer 
d'afficher mon émojis ligaturer avec `fmt` sans succès (il y avait toujours deux caractères d'affiché),
j'ai fait une conversion de type par inadvertance et ç'a fonctionné !. Je n'ai aucune idée de pourquoi j'ai eu besoins de deux heures pour ça.

On a maintenant nos émojis de toutes les couleurs ! :tada:

{{< illustration src="img/search-ok-hand-black.png"        name="Résultat de la recherche ok hand"            alt="Résultat de la recherche `ok hand` affichant toutes les variations de couleur de l'émoji de base" >}}

## :no_entry_sign: émojis incompatible

Mon ordinateur et mon téléphone ne supportent pas bien les émojis publier après la version 14. Mais comme je l'ai dit plus tôt, la beauté des ligatures de l'UTF-8,
c'est que malgré ça, je vois quand même les différents composants. De cette façon, je ne perds pas le sens original.

{{< illustration src="img/search-ok-no-ligature.png"        name="Résultat de la recherche pour des émojis ne supportant pas les variations"            alt="Plusieurs émojis `couple with heart man man` qui affiche la couleur de peau dans un second caractère, un carré de la couleur" >}}

Si vous voulez tester par vous-même et bidouiller le code, vous pouvez trouver le code complet et fonctionnel sur ce repository: [git2.riper.fr/ztec/emoji-search-engine-go](https://git2.riper.fr/ztec/emoji-search-engine-go).

## :interrobang: Pourquoi j'ai fait tout ça ?

Déjà, pourquoi pas ? Juste jouer avec des émojis c'est fun. Mais surtout, mon but était d'avoir un moteur de recherche d'émojis sous la main pour que
je puisse copier les émojis ailleurs. Tous les systèmes que j'ai trouvés en ligne me semblais inadapté et pénible à utiliser. 

 - Beaucoup trop lent a charger et chercher.
 - Beaucoup trop inutile,Je ne souhaite pas chercher mon émojis dans une liste interminable d'icon jaune. 

La meilleure solution que j'avais trouvée, c'était un raccourci vers le fichier du site Unicode. Mais comme les noms d'usage ne sont pas tous inclus j'ai dû apprendre les versions officielles. 
Puis un jour, le site d'Unicode est tombé et n'était plus disponible pendant quelques heures. 

Ouais, je dois être le seul au monde qui sait quand le site d'Unicode tombe, et surtout qui est impacté par ça ! :rofl:

## :next_track_button: Et la suite ? 

Ce moteur est vraiment simple, basic. Il y a plein de façon de l'améliorer. J'ai d'ailleurs déjà inclus une recherche inverse même si je n'en ai pas parlé ici.
Bleve est puissant malgré tout, mais rate certains cas évidents. Je vais voir ce qui me dérange le plus et l'amélioré 
en fonction de ça. Peut-être que le résultat sera open-source un jour, mais pour ça je doit encore faire du ménage dans mon projet. 
Les émojis ne sont pas les seuls trucs que je "cherche" dans mon moteur de recherche. :wink:

Merci infiniment de m'avoir lu,\
[Bisoux](/page/bisoux) :kissing:
