# :octocat: digit.nvim

Open up specific git revisions of a file.

https://github.com/austinliuigi/digit.nvim/assets/85013922/3204b646-42a6-46a2-8b03-229c58cdf3a9

## Configuration

```lua
require("digit").setup({
    default_view = "tab", -- "replace"|"split"|"vsplit"|"tab"
})
```

## Usage

```
:DigitOpen <rev> [view]
```

> Note: `<rev>` does not need to specify a file, in which case the current
> buffer's file will be opened

### Examples

1. `:DigitOpen HEAD~2 vsplit`
    - opens up the current file as it was 2 commits ago in a vertical split
2. `:DigitOpen a1b2c3:foo/bar/baz.md`
    - opens up specific file `<repo_root>/foo/bar/baz.md` as it was in commit `a1b2c3`
