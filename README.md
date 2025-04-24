# MirrorMark

A minimal Neovim plugin to bi-directionally sync your Markdown files with any rclone-compatible remote (e.g., Nextcloud WebDAV, S3, Google Drive). Perfect for note-takers using [`zettelkasten.nvim`](https://github.com/Furkanzmc/zettelkasten.nvim) or any other Markdown-based system.

If you're using this, star the repo!

Credit to ChatGPT and StackOverflow for much-needed assistance.

## ✨ Features

- **True bi-directional sync** via `rclone bisync` on startup (`VimEnter`).
- **Instant file-level sync** on every Markdown save (`BufWritePost`) using `rclone copyto` (push then pull) for minimal latency.
- **Customizable remotes**: works with any remote you configure in `rclone config` (WebDAV, S3, etc.).
- **Multiple folders**: mirror several local roots to different remote subfolders.
- **Lightweight**: no heavy dependencies; just a single `rclone` binary.

## 🔧 Installation

First, install and configure [rclone](https://rclone.org/):

1. Download the latest `rclone` binary and place it on your `$PATH`.
2. Run `rclone config` and set up a remote (e.g. `nc-webdav`) pointing to your Nextcloud (or other) endpoint.

### With `lazy.nvim`

````lua
{
  "Rom3dius/mirrormark",
  config = function()
    require('mirrormark').setup({
      -- list of folders to sync
      folders = {
        '~/YOUR_NOTES',
      },

      -- rclone remote alias (must match a remote in `rclone config`)
      rclone_remote = 'nc-webdav',

      -- subfolder inside the remote for all sync roots
      remote_subdir = 'md-sync',

      -- optional: path to a custom rclone binary
      rclone_binary = '/usr/local/bin/rclone',
    })
  end,
}


#### Development

1. Install the pre-commit

```bash
make setup
make check-secrets
````

This isn't ironclad, small passwords WILL slip through this pre-commit.

2. Add local copy of the plugin to Neovim

```lua
{
  dir = "~/src/mirrormark",
  config = function()
    require("mirrormark").setup({
      folders = { "~/YOUR_NOTES" },
      rclone_remote = "YOUR_RCLONE_REMOTE",
      remote_root = "YOUR_NOTES_FOLDER",
    })
  end,
}
```
