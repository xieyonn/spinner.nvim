# Changelog

## [1.3.0](https://github.com/xieyonn/spinner.nvim/compare/v1.2.0...v1.3.0) (2026-02-14)


### Features

* ignore check CHANGELOG.md ([a653714](https://github.com/xieyonn/spinner.nvim/commit/a6537149a568750cb1e492a469ee4a87d6069a68))


### Bug Fixes

* on_update_ui pass hl_group field ([b5d577d](https://github.com/xieyonn/spinner.nvim/commit/b5d577df5745c0eab1bbf3db3492680653c1f634))

## [1.2.0](https://github.com/xieyonn/spinner.nvim/compare/v1.1.0...v1.2.0) (2026-02-14)


### Features

* support install by rocks.nvim ([f0b593b](https://github.com/xieyonn/spinner.nvim/commit/f0b593b35149f5b0a25b4c4cd92543a433ddb8ef))


### Bug Fixes

* setup() placeholder and hl_group with table ([c612e4a](https://github.com/xieyonn/spinner.nvim/commit/c612e4ab6b23850f09e2aff49aa9e9aab55cec95))
* setup() placeholder and hl_group with table ([#85](https://github.com/xieyonn/spinner.nvim/issues/85)) ([3ad4b99](https://github.com/xieyonn/spinner.nvim/commit/3ad4b999389b0aa56c39c24cac507d2b85238e4f))

## v1.1.0 - (2026-02-13)

### Highlights

- Add api `reset()`
- Extend the `placeholder` and `hl_group` options to display different content in different states.
- Apply hl_group in statusline/tabline/winbar, will keep backward compatibility by default.

### Features

- feat: remove opts.fmt check in render, check it in config by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/62
- feat: add check for custom spinner, use id as ui_scope by default by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/63
- feat: use notify_once by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/64
- docs(reame): misc by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/65
- feat: add spinner pattern blink by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/66
- feat(hlgroup): apply hlgroup in statusline/tabline/winbar by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/67
- test(hlgroup): add test case for placeholder = false by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/68
- feat: statusline/tabline/winbar set opts.hl_group = nil for backward … by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/69
- feat: update ui when call config. by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/71
- feat: add STATUS.INIT and extend hl_group and placeholder by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/70
- fix: cursor spinner shoud use default hl_group Spinner by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/72
- feat: add api reset by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/73
- Revert "feat: add api reset" by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/75
- feat: add api reset by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/76
- feat: remove duplicate check for STATUS.INIT by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/77
- docs(readme): add example for todo list by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/78
- feat: scheduler reduces call now_ms() by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/79
- docs(readme): misc by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/80
- docs(readme):misc by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/81

## v1.0.4 - (2026-02-11)

### Highlights

- Add window-title, window-footer spinner https://github.com/xieyonn/spinner.nvim/pull/55

### Features

- docs: misc https://github.com/xieyonn/spinner.nvim/pull/54 https://github.com/xieyonn/spinner.nvim/pull/57 https://github.com/xieyonn/spinner.nvim/pull/58 https://github.com/xieyonn/spinner.nvim/pull/61
- feat: stop spinner if fail to update extmark by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/56
- test: add more test cases https://github.com/xieyonn/spinner.nvim/pull/60 https://github.com/xieyonn/spinner.nvim/pull/59

## v1.0.3 - (2026-02-10)

### Highlights

- Add a api `require("spinner.demo").open() `to preview spinners. https://github.com/xieyonn/spinner.nvim/pull/49 https://github.com/xieyonn/spinner.nvim/pull/52

### Features

- ci: add `doc/tags` to `.gitignore` by @DrKJeff16 in https://github.com/xieyonn/spinner.nvim/pull/42
- feat: add option cmdline_cursor.hl_group in setup by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/43
- feat: codecov 80 is reasonable by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/44
- docs(readme): misc by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/45 https://github.com/xieyonn/spinner.nvim/pull/47 https://github.com/xieyonn/spinner.nvim/pull/53
- docs: luadoc for deduplicate_list by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/48
- feat(extmark): add option virt_text_pos, virt_text_win_col by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/51
- feat: optimized code, improved annotations accross the board by @DrKJeff16 in https://github.com/xieyonn/spinner.nvim/pull/46

### Bug Fixes

- fix: shark pattern by @xieyonn in https://github.com/xieyonn/spinner.nvim/pull/41
- fix(demo): make window focusable by @DrKJeff16 in https://github.com/xieyonn/spinner.nvim/pull/50

## v1.0.2 - (2026-02-09)

- fix: add missing setup() @DrKJeff16 #38
- feat: use vim.api.nvim\_\_redraw if possible @phanen #37
- feat: simper vim.validate @DrKJeff16 #39
- docs: misc

## v1.0.1 - (2026-02-08)

- fix: custom spinner accept option ui_scope.
- feat: schduler keep task order as FIFO.
- docs: misc.

## v1.0.0 - (2026-02-08)

first stable release!
