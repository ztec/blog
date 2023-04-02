---
title: "🐙 Search engine for emoji in go"
date: 2023-04-02T01:00:00+02:00
slug: "emoji-search-engine"
tags: ["tech", "go", "emoji"]
---

For a project of mine, I had to handle emoji. The goal was to do a little search engine to find emoji because reasons. 
I'm not starting from scratch and have to include my code into an already existing program in go.
So lets go and see how to build a little search engine for emojis in go.

TL;DR; the full results is available here: [git2.riper.fr/ztec/emoji-search-engine-go](https://git2.riper.fr/ztec/emoji-search-engine-go)

## :boar: Emoji! Get them all! 

First, I had to find the list of all emoji available. Easy ! You can
see it on hte official Unicode website

https://unicode.org/Public/emoji/15.0/emoji-test.txt

This file look like this

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

Basically, there is the unicode code, the character itself and a description. The file is
dedicated for machines, so it should not be hard to load it and parse it.

Before starting heads down, lets do our due diligence and check what the community already done.

I found

- [github.com/enescakir/emoji](https://github.com/enescakir/emoji) last update 2020
- [AkinAD/emoji](https://github.com/AkinAD/emoji) last update 2022 (fork of the first)
- [github.com/kenshaw/emoji](ttps://github.com/kenshaw/emoji) last update 2021

Looking to the code of those library, I find something
fascinating : https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json
This file, updated regularly, is perfect and can be parsed with less effort. Moreover, it already contains some metadata
like aliases.

It's decide, lets load this file

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

I used `github.com/go-zoox/fetch` to fetch the file just because I'm a lounger

## :llama: Emoji, Index them all! 

In my program, I already use [Bleve](https://blevesearch.com/) to index and search though other things, so I will
do the same here. The operation is pretty simple as I do not have to store anything and can keep an in memory index.

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

func indexEmojies() error {
	// we create a new indexMaping. I used the default one that will index all fields of my EmojiDescription
	mapping := bleve.NewIndexMapping()
	// we create the index instance
	bleveIndex, err := bleve.NewMemOnly(mapping)
	if err != nil {
		return err
	}
	// we fetch the emoji from the internet. This can fail, and may be embeded for better performance
	e, err := fetchEmojiFromGithub()
	if err != nil {
		logrus.WithError(err).Error("Could fetch emoji list")
		return err
	}
	emojis = e
	for eNumber, eDescription := range emojis {
		// this will index each item one by one. No need to be quick here for me, I can wait few ms for the program to start.
		err = bleveIndex.Index(fmt.Sprintf("%d", eNumber), eDescription)
		if err != nil {
			logrus.WithError(err).Error("Could not index an emoji")
		}
	}
	index = bleveIndex // we make the index available
}
```

Once `indexEmojies` is called, I have an `index` ready to be used to search for emoji. Let's test it

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

I decided to use the `NewQueryStringQuery` as it allow [many option](https://blevesearch.com/docs/Query-String-Query/) of search directly from the query string.
I will be able to search within fields, or add modifier. I use it a lot for my other purpose, it might be less useful here but 
do not cost a lot, so I kept it.

> Open you mind and imagine a clip-show of me adding the above code in my program and creating the interface to send the query and display 
> the results.

{{< photo-gallery >}}
{{< photo src="img/search-ok-grin.png"        name="Search results for grin"            alt="Search result for the query `grin` displaying the `grin` emoji as expected" >}}
{{< photo src="img/search-ok-smile.png"       name="Search results for smile"           alt="Search result for the query `smile` displaying multiple emoji smiling" >}}
{{</photo-gallery>}}

## :bubble_tea: Fuzzy search 

Cool, the results seems promising. Bet there is a problem

{{< illustration src="img/search-ko-hug.png"        name="Search results for hug"            alt="Search result for the query `hug` displaying no results" >}}

I should have an emoji here, :hugs: to be exact. If I add the `s` to the query it finds it, but not without it. Lets try
to enhance the search for this kind of purpose by adding a bit of Fuzziness to the search.

The idea is to allow some inexact work to match the query. For that we will use what's called [Levenshtein distance](https://en.wikipedia.org/wiki/Levenshtein_distance).
In fact, as I already said, I'm a slacker so bleve will do it for me. Unfortunately, I could not find any way
to add a default fuzzy parameter to `query` search. I still can add `~` to words of my search to enable fuzzy search on it.
As my expectation are not hight, I will do it `just hack it` way. If I have no results from the query I will do specific
fuzzy search instead.

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
{{< illustration src="img/search-ok-hug.png"        name="Search results for hug"            alt="Search result for the query `hug` now displaying multiple emoji including hugs" >}}

This time, I have my `hugs` emoji when I search for `hug`. I also have other results, but that's fine for me. I don't expect
to have only one results and picking the right one as long as it is visible on screen with few to no scroll it's ok for me. 

> side note: I could have also used prefix search, but I don't always search using the beginning of emojis name, so I prefer using the fuzzy search.

## :purple_square: Skin tones

If I search for `ok hand` I find the emoji right. But as you can see, there is only the standard variation. The yellow one.
I would like to have the skin tone variation as well. 

{{< illustration src="img/search-ok-hand-no-black.png"        name="Search results for ok hand"            alt="Search result for the query `ok hand` displaying only the yellow emoji" >}}

> Open your mind again and imagine a narrator with a deep voice pop in your head and says the following:
> "Zed did not know hard it will be to include those fancy skin toned emojis. Hours will pass before he finally understands"

Before continuing, I need to explain (what I understood) how emoji and UTF8 works for skin tone variations.
UTF8 characters can be composed together. This allows to create what we call [ligatures](https://en.wikipedia.org/wiki/Ligature_(writing)).
Basically, you take the code of two character, and you smash them together in one UTF8 character. On your screen, if you reader and font is compatible
you will see a different character in place of the two characters. The beauty of the thing is that even if your reader or font are not compatible, you
will see the originals characters anyway. Cool right.

Emoji skin tone is handle like this. You "smash" together the original emoji and the skin tone color to create a new emoji of the original one but the 
yellow is replaced by the skin tone.

```
1F44C                                                  ; fully-qualified     # 👌 E0.6 OK hand
1F44C 1F3FB                                            ; fully-qualified     # 👌🏻 E1.0 OK hand: light skin tone
1F44C 1F3FC                                            ; fully-qualified     # 👌🏼 E1.0 OK hand: medium-light skin tone
1F44C 1F3FD                                            ; fully-qualified     # 👌🏽 E1.0 OK hand: medium skin tone
1F44C 1F3FE                                            ; fully-qualified     # 👌🏾 E1.0 OK hand: medium-dark skin tone
1F44C 1F3FF                                            ; fully-qualified     # 👌🏿 E1.0 OK hand: dark skin tone
```
The first column contains the UTF8 code for each emoji. As you can read, the first one is the same and is the `ok_hand` emoji
itself. The second code, is the skin tone. So we have the list of each skin tone available.

```go
	tones := map[string][]rune{
      "light skin tone" : []rune("\U0001F3FB"),
      "medium-light skin tone" : []rune("\U0001F3FC"),
      "medium skin tone" : []rune("\U0001F3FD"),
      "medium-dark skin tone" : []rune("\U0001F3FE"),
      "dark skin tone" : []rune("\U0001F3FF"),
	}
```
Original library, and most library I saw handle emoji as string and play with them with string using the `\Uxxxxxxxx` format.
Golang has a type dedicated to UTF8 character management, the `rune`. I decided to use it. Unfortunately, this is not really coming and
there is really few example online of rune usage; even less with ligatures.
I used the string representation to easily make the connection between the UF8 code and the runes in go.

Now, we need to create a new emoji for each skin tone. Not all emoji can support skin tone. I could parse the original
unicode file, but, if you paid attention, the json file I fetch already have this information.

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

The key :key: here is this line: 
```go
currentEmojiWithSkinTone.Emoji = string(append([]rune(currentEmojiWithSkinTone.Emoji), tone...))
```
I'm no expert in go, and I probably missed something, but after hours playing with `fmt` to print the emoji with ligature
and failing with always two characters displayed, I inadvertently used the type conversion, and it worked. I have
no idea why it took me two :fu-dark-skin-tone: hours to do it. 

We now have our skin tone variation :tada:

{{< illustration src="img/search-ok-hand-black.png"        name="Search results for ok hand"            alt="Search result for the query `ok hand` now displaying all the color variations" >}}

## :no_entry_sign: Unsupported Emoji

My computer and my phone does not support well emoji version 14 and higher. But as I said earlier, the beauty of UTF8 ligatures
is that even if you cannot process them fully, you get the characters. This way you can still understand the intention.

{{< illustration src="img/search-ok-no-ligature.png"        name="Search results with unsupported skin toned emoji"            alt="Multiple emoji `couple with heart man man` with skin tone displayed as two emoji. The original one + the skin tone itself as a square" >}}

If you want to test is yourself and tinker with it, you can find the full working example ins this repository [git2.riper.fr/ztec/emoji-search-engine-go](https://git2.riper.fr/ztec/emoji-search-engine-go)


## :interrobang: Why did I do all of that ? 

First of all, why not. Just playing with emoji is fun, sort of. But mostly, my goal was to have on hand an emoji finder to easily copy them elsewhere. 
Every system I found online had flaws that were annoying. 
 - way too slow to load or search
 - way too useless. I don't want to search for my emoji in a huge list of yellow icons 

The best solution I had was a shortcut to the unicode list itself. Not all common names are present,
so I had to learn some official names. The big reason I decided to build my own search "engine" on that is "unicode website was down!" :arrow_down:

Yeah, I might be the only one in the world that know that the unicode website sometime does not respond, and be impacted by that! :rofl:

## :next_track_button: What's next ? 

This engine is really simple and stupid. There is already ways to improve it. I already have included a reverse search even if 
I did not talk about that here. The indexing engine is somewhat powerful and cool, but still miss some obvious cases. I'll
see upon usage what's bothering me the most and improve it. Maybe the result will be open-sourced but for that I have 
a lot to do. Emoji are not the only things I have in my little search engine :wink:

Thank you reading this,\
[Bisoux](/page/bisoux) :kissing:
