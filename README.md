# xdg-mime.yazi

Simple (most likely overengineered) to quickly retrieve a file's xdg based mimetype in [yazi](https://github.com/sxyazi/yazi).

## What does it do?

This plugin provides a easy way to access the results of `xdg-mime query filetype <the file>`, and copy that, for easier configuring of `xdg-open`

## Usage

Select any number of files, press the assigned keybind, and wait (if you have alot of files).

## Installation

You will need to be able to run `xdg-mime`, not much else is needed.

### keymap.toml
```toml
[[manager.prepend_keymap]]
on = "<S-x>"
run = "plugin xdg-mime"
```

## What does it really do?

This was meant as a excersize to learn how to create plugins, now published, for whatever use anyone might get from it.
