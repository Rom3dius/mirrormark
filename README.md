# md_nextcloud_sync

A minimal Neovim plugin to sync markdown files to Nextcloud via WebDAV. Ideal for users who take notes in markdown—whether you're using [`zettelkasten.nvim`](https://github.com/Furkanzmc/zettelkasten.nvim) or any other system.

If you're using this, star the repo!

Credit to ChatGPT and StackOverflow for much needed assistance.

## ✨ Features

- Syncs all markdown files from one or more local folders to your Nextcloud server.
- Automatically uploads on Neovim startup and every time a markdown file is saved.
- Designed for use with [`zettelkasten.nvim`](https://github.com/Furkanzmc/zettelkasten.nvim) untested but should work with any markdown notes / markdown wiki plugin.

## 🔧 Installation

Create the root folder you would like your notes synced to in Nextcloud.
OPTIONAL: Create an app password for the plugin to use instead of your real password.

### With `lazy.nvim`

#### Remote (GitHub)

```lua
{
  "Rom3dius/md_nextcloud_sync",
  config = function()
    require("md_nextcloud_sync").setup({
      folders = { "~/YOUR_NOTES", "~/YOUR_EXTRA_NOTES" },
      nextcloud_user = os.getenv("NEXTCLOUD_USER"),
      nextcloud_pass = os.getenv("NEXTCLOUD_PASS"),
      nextcloud_url = "https://your-nextcloud-domain/remote.php/dav/files/YOUR_USERNAME/YOUR_NEXTCLOUD_NOTES_FOLDER/"
    })
  end,
}
```

#### Development

1. Install the pre-commit

```bash
make setup
make check-secrets
```

This isn't ironclad, small passwords WILL slip through this pre-commit.

2. Add local copy of the plugin to Neovim

```lua
{
  dir = "~/path/to/md_nextcloud_sync",
  config = function()
    require("md_nextcloud_sync").setup({
      folders = { "~/YOUR_NOTES", "~/YOUR_EXTRA_NOTES" },
      nextcloud_user = os.getenv("NEXTCLOUD_USER"),
      nextcloud_pass = os.getenv("NEXTCLOUD_PASS"),
      nextcloud_url = "https://your-nextcloud-domain/remote.php/dav/files/YOUR_USERNAME/YOUR_NEXTCLOUD_NOTES_FOLDER/"
    })
  end,
}
```
