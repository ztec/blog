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

#### with Compose

The default development target runs Hugo 0.152.2 through Compose. Make prefers
Podman when it is installed and falls back to Docker:

```cmd
make dev
```

The site is available at [http://localhost:1313](http://localhost:1313) by
default; set `PORT` to use another local port. Set `CONTAINER_ENGINE` to bypass
automatic selection for any container-backed Make target:

```sh
make CONTAINER_ENGINE=docker dev
```

When Podman delegates Compose to Docker Compose, `make dev` starts the rootless
Podman API socket automatically. It remains active for the user session so
Compose can finish stopping its containers cleanly; it is not enabled across
login sessions. Stop it manually with `systemctl --user stop podman.socket` if
desired.

#### directly with Hugo

To use a locally installed [Hugo](https://gohugo.io/getting-started/quick-start/)
instead of Docker, run:

```cmd
make local-dev
```

### Deployment

Production releases are built from the repository's `Dockerfile` and uploaded
to Bunny Storage. Each immutable release is stored under a dated site folder. A
managed host edge rule is then switched to the new folder, the complete
pull-zone cache is purged, and the configured number of rollback alternatives
is retained.

All non-secret Bunny settings live exclusively in the `[params.bunny]` table in
`config.toml`. This table is the authoritative place to change the API URL,
storage zone, site folder and hostname, pull-zone ID, edge-rule identity,
ordering and pattern, release retention, or upload concurrency. The deployer
does not accept environment overrides for these values.

The storage zone must be created manually before the first deployment. Set the
bunny.net account API key in the environment; the deployer uses it to resolve
the storage zone ID, regional endpoint, and storage password.

```sh
export BUNNY_API_KEY='...'
export PP_HOST='https://photos.example.net'
export PP_TOKEN='...'
./bin/deploy.sh deploy
```

The account key needs access to the storage zone and pull zone declared in
`config.toml`. Keep API keys and service credentials out of that file; they are
provided only through the environment.

List rollback targets; the live edge-rule target is marked `current`:

```sh
./bin/deploy.sh list
# Equivalent:
./bin/deploy.sh rollback list
```

Switch to a retained release and purge the cache:

```sh
./bin/deploy.sh rollback 2026-09-07T120000Z-0123456789ab
```

`./bin/deploy.sh prune` retries retention cleanup and
`./bin/deploy.sh purge` retries the full pull-zone cache purge. The deployer
refuses to overwrite an existing release.

Forgejo Actions uses the same `./bin/deploy.sh deploy` command. Configure these
repository values before enabling the workflow:

- Secret `BUNNY_API_KEY` (required)
- Secret `PP_TOKEN` (required by PhotoPrism-backed Hugo shortcodes)
- Secret `PP_HOST` (required by PhotoPrism-backed Hugo shortcodes)

The previous Kubernetes manifests remain in `k8s/` for emergency fallback and
can be removed after the BunnyCDN production cutover is verified.

The wrapper uses Docker by default. Set `BUNNY_CONTAINER_ENGINE=podman` when
running it with Podman instead.

#### Build cache

The deployment wrapper persists Hugo's download cache and processed resources
in `.cache/hugo/`. Local runs mount the source read-only and the cache
read-write, preserving the caller's UID/GID. The generated `public/` output is
never cached and every release still starts from a clean destination.

Forgejo Actions cannot bind-mount runner folders into its Docker containers, so
it enables `BUNNY_DEPLOY_COPY_MODE=true`. In this mode the wrapper streams the
checked-out source and restored cache through `docker cp`, runs the same
deployment image without volumes, and copies the updated cache back afterward.
`actions/cache@v4` then saves `.cache/hugo/`. Its key includes the Hugo version
and relevant source files, with a fallback to the newest compatible cache when
content changes.

Override the host cache location when a runner provides a durable volume:

```sh
export BUNNY_HUGO_CACHE_DIR=/var/cache/forgejo/blog-hugo
./bin/deploy.sh deploy
```

The override may also be relative to the repository root. Cache contents are
disposable; remove the directory when troubleshooting a suspected stale Hugo
artifact and the next deployment will recreate it.

Copy mode can also be exercised manually on a machine where Docker bind mounts
are unavailable:

```sh
BUNNY_DEPLOY_COPY_MODE=true ./bin/deploy.sh deploy
```


## License

All code and content is licensed under [Creative Commons BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.en), except for content with a specific license mentioned below.

### Third-Party Assets

#### Chest Icon
- **License**: CC Attribution License
- **Author**: [Dazzle UI](https://dazzleui.gumroad.com/l/dazzleiconsfree?ref=svgrepo.com)

#### Article Icon
- **License**: CC0 License
- **Source**: [SVG Repo](https://www.svgrepo.com/svg/213030/article)

#### Triangle Icon (Concert)
- **Collection**: Music Line Vectors
- **License**: CC Attribution License
- **Author**: [wishforge.games](https://www.svgrepo.com/author/wishforge.games/)

#### Artists Icon
- **Collection**: [Avatars 10](https://www.svgrepo.com/collection/avatars-10/)
- **License**: CC0 License
- **Uploader**: [SVG Repo](https://www.svgrepo.com/)

#### Saxophone Icon (Instruments)
- **Collection**: Retro Pixel Icons
- **License**: CC Attribution License
- **Author**: [Buninux](https://buninux.gumroad.com/l/lfdy?ref=svgrepo.com)

#### Dinosaur Kids Play SVG Vector
- **Collection**: Kids Toys Line Vectors
- **License**: CC Attribution License
- **Author**: [Dooder](https://dribbble.com/Dooder)
- **Source**: [SVG Repo](https://www.svgrepo.com/author/Dooder/)
