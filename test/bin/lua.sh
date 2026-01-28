#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
export ROOT_DIR

TEST_XDG_HOME="$ROOT_DIR/.xdg"
if [[ -d "$TEST_XDG_HOME" ]]; then
    rm -rf "$TEST_XDG_HOME"
fi

for dir in "config" "data" "state" "cache"; do
    export "XDG_${dir^^}_HOME"="$TEST_XDG_HOME/${dir}"
    mkdir -p "$TEST_XDG_HOME/${dir}"
done

export LUA_PATH="$LUA_PATH;$ROOT_DIR/lua/?.lua;$ROOT_DIR/lua/?/init.lua;"
export LUA_PATH="$LUA_PATH;$ROOT_DIR/test/?.lua;$ROOT_DIR/test/?/init.lua;"
export LUA_PATH="$LUA_PATH;$(luarocks path --lr-path)"
export LUA_CPATH="$LUA_CPATH;$(luarocks path --lr-cpath)"

while getopts 'ilEve:' opt; do
    # shellcheck disable=SC2220
    case $opt in
        e) lua_expr=$OPTARG ;;
        v)
            nvim --version
            exit 0
            ;;
        i | l | E)
            echo "Option '$opt' not supported by shim"
            exit 1
            ;;
    esac
done

if [ -n "$lua_expr" ]; then
    nvim --headless -c "lua $lua_expr" -c 'quitall!'
else
    nvim -l "$@"
fi
