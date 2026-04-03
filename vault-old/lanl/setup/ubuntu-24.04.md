#! /usr/bin/env bash

apt install net-tools

apt update
apt upgrade -y

apt install -y net-tools build-essential gfortran clang unzip gnupg2 python3-dev python3.12-venv lmod ninja-build doxygen subversion python3-pip pipx htop cmake-curses-gui pkg-config graphviz bear python3-sphinx python3-sphinx-rtd-theme neovim ca-certificates netpbm nodejs npm rust-all gettext xsel ripgrep fd-find eza poppler-utils texlive texlive-latex-extra mupdf lua5.1 luarocks

systemctl enable apport.service

npm install -g tree-sitter-cli
pipx install cmake-language-server
pipx install pyright
