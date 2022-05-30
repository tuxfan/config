"------------------------------------------------------------------------------"
" vimrc
"------------------------------------------------------------------------------"

"------------------------------------------------------------------------------"
" Turn on syntax highlighting.
"------------------------------------------------------------------------------"

syntax on

"------------------------------------------------------------------------------"
" Italic comments.
"------------------------------------------------------------------------------"

highlight Comment cterm=italic

"------------------------------------------------------------------------------"
" Enable filetype extensions:
"   plugin - enable loading plugin file for specific file types.
"   indent - enable loading indent file for specific file types.
"------------------------------------------------------------------------------"

filetype plugin indent on

"------------------------------------------------------------------------------"
" Set tab and indent parameters:
"   ts (tabstop)
"   sts (soft tabstop)
"   sw (shift width)
"   et (expandtab)
"   ai (auto indent)
"   si (smart indent)
"------------------------------------------------------------------------------"

set ts=2 sts=2 sw=2 et ai si

"------------------------------------------------------------------------------"
" Set relative line numbers
"------------------------------------------------------------------------------"

set rnu
highlight LineNr ctermfg=red

"------------------------------------------------------------------------------"
" Highlight cursor line underneath the cursor horizontally.
"------------------------------------------------------------------------------"

set cursorline

"------------------------------------------------------------------------------"
" Give more space for displaying messages.
"------------------------------------------------------------------------------"

set cmdheight=2

"------------------------------------------------------------------------------"
" Plugins
"------------------------------------------------------------------------------"

call plug#begin()
Plug 'neoclide/coc.nvim'
Plug 'jiangmiao/auto-pairs'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'preservim/nerdtree'
call plug#end()

"------------------------------------------------------------------------------"
" GoTo code navigation.
"------------------------------------------------------------------------------"

nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

"------------------------------------------------------------------------------"
" Set theme for terminal information.
"------------------------------------------------------------------------------"

let g:airline_theme='raven'

"------------------------------------------------------------------------------"
" Use <tab> for trigger completion and navigate to the next complete item.
"------------------------------------------------------------------------------"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~ '\s'
endfunction

inoremap <silent><expr> <Tab>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<Tab>" :
      \ coc#refresh()

"------------------------------------------------------------------------------"
" Coc config shortcut.
"------------------------------------------------------------------------------"

function! SetupCommandAbbrs(from, to)
  exec 'cnoreabbrev <expr> '.a:from
        \ .' ((getcmdtype() ==# ":" && getcmdline() ==# "'.a:from.'")'
        \ .'? ("'.a:to.'") : ("'.a:from.'"))'
endfunction

" Use C to open coc config
call SetupCommandAbbrs('C', 'CocConfig')

"------------------------------------------------------------------------------"
" Shortcut for Nerd Tree sidebar.
"------------------------------------------------------------------------------"

inoremap <c-c> <Esc>:NERDTreeToggle<cr>
nnoremap <c-c> <Esc>:NERDTreeToggle<cr>
