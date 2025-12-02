Zed's place
==========

This repository contains source code of my personal blog https://blog.ztec.fr


### Contribution

Contribution are welcome as long as they do not alter the meaning
of the content. If you rather comment, you can go directly on https://blog.ztec.fr, find the page and use social media link at the end to engage discussion either on Twitter or Mastodon.

If you want to suggest a grammar, spelling or typo fix, this is the place. Please open a PullRequest (on the Github mirror). 
I will be happy to merge it as long as you do not alter the original meaning of the text.

I plan to add contributors names on article pages where they contributed. This is not in place for now, but consider
it. If you want to suggest modification anonymously (specify it) or do not wish to use Github, send me a git patch via mail to `patch.blog@riper.fr` 

### Development

#### directly with hugo
To run the server, simply [install hugo](https://gohugo.io/getting-started/quick-start/) and then execute this command
in the root blog folder.

```cmd
hugo server -p 8080
```

#### with docker

You need docker and docker compose.

```cmd
docker compose up dev
```

You can also test the final version with

```cmd
docker compose up prod
```

then go to [http://localhost:8080](http://localhost:8080)


## License

All code and content is licensed under [Creative Commons BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.en), except for content with a specific license mentioned below.

### Third-Party Assets

#### Chest Icon
- **License**: CC Attribution License
- **Author**: [Dazzle UI](https://dazzleui.gumroad.com/l/dazzleiconsfree?ref=svgrepo.com)

#### Article Icon
- **License**: CC0 License
- **Source**: [SVG Repo](https://www.svgrepo.com/svg/213030/article)


 