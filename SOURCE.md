# Corresponding source

The prebuilt `koreader-bookeen-*.zip` release asset contains KOReader, which is
licensed under the **GNU Affero General Public License v3.0 or later**.

## Upstream source

- Repository: <https://github.com/koreader/koreader>
- Commit: `035e00b21d0286325ef2e8a7e3b6326f340e2ded`
- Build target: `bookeen`
- Build command: `./kodev release --ignore-translation bookeen`
  (the translation refresh is skipped so the pinned `l10n` submodule is preserved)

Submodules at that commit:

```
base                                     007ac6a81e2de4822c8df7ce57b8dbb06aa3b8ea
base/thirdparty/kpvcrlib/crengine        f335f7a97e240f505bb8a0dfb721fcb7912a7824
l10n                                     be4726d0fa58195dbe6f2b868ddafd2b18e472d9
platform/android/luajit-launcher         e0c3c861b043966a8d845392f10d64da095f99bc
resources/fonts                          046976988aa33639d60d6ffd25c7a0ff50b72ac0
test                                     c3b5d06e1ae8ea088bd898b0e7f9da3753d0d86c
```

Docker build image:

```
koreader/kobookeen:latest
digest sha256:951afceead5bdaae7f1cadc2b47f7618955669b8fba675439e41accfe9329750
```

The official image tag can move. For a long-term reproducible build, use the digest
above.

## How to obtain the source

Either:

```sh
git clone --recurse-submodules https://github.com/koreader/koreader.git
cd koreader
git checkout 035e00b21d0286325ef2e8a7e3b6326f340e2ded
git submodule update --init --recursive
```

or build with this repository:

```sh
./scripts/build-koreader.sh
./scripts/make-source.sh
```

`scripts/make-source.sh` produces `dist/koreader-source-<version>.tar.gz`, which is
attached to the GitHub release.

## This repository's code

The installer, shim, host scripts, and documentation are licensed AGPL-3.0-or-later.
See [LICENSE](LICENSE).
