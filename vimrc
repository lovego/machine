set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'
Plugin 'scrooloose/nerdTree'
Plugin 'fholgado/minibufexpl.vim'
Plugin 'godlygeek/tabular'
Plugin 'terryma/vim-multiple-cursors'
Plugin 'ntpeters/vim-better-whitespace'
Plugin 'fatih/vim-go'
Plugin 'chr4/nginx.vim'
Plugin 'ekalinin/Dockerfile.vim'
Plugin 'solarnz/thrift.vim'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required

let g:multi_cursor_exit_from_visual_mode = 0
let g:multi_cursor_exit_from_insert_mode = 0
let g:go_fmt_command = "goimports"

syntax on
set fencs=utf8,gbk
set number ruler hlsearch expandtab shiftwidth=2 tabstop=2 backspace=2
autocmd filetype go setlocal expandtab
" autocmd vimenter * NERDTree
colo desert
highlight ColorColumn ctermbg=255
set colorcolumn=101
set backupcopy=yes " prevent inode number changes

" Search for selected text, forwards or backwards.
vnoremap <silent> * :<C-U>
  \let old_reg=getreg('"')<Bar>let old_regtype=getregtype('"')<CR>
  \gvy/<C-R><C-R>=substitute(
  \escape(@", '/\.*$^~['), '\_s\+', '\\_s\\+', 'g')<CR><CR>
  \gV:call setreg('"', old_reg, old_regtype)<CR>
vnoremap <silent> # :<C-U>
  \let old_reg=getreg('"')<Bar>let old_regtype=getregtype('"')<CR>
  \gvy?<C-R><C-R>=substitute(
  \escape(@", '?\.*$^~['), '\_s\+', '\\_s\\+', 'g')<CR><CR>
  \gV:call setreg('"', old_reg, old_regtype)<CR>

syn match markdownError "\w\@<=\w\@="

