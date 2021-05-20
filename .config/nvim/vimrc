"=========== Plugin Section ==============
call plug#begin("~/.vim/plugged")
  Plug 'scrooloose/nerdtree'
    Plug 'Xuyuanp/nerdtree-git-plugin'
    Plug 'ryanoasis/vim-devicons'
    Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
  Plug 'itchyny/lightline.vim'
  Plug 'liuchengxu/vim-which-key', { 'on': ['WhichKey', 'WhichKey!'] }
  Plug 'dense-analysis/ale'
  Plug 'itchyny/vim-gitbranch'
  Plug 'tpope/vim-commentary'
  Plug 'tpope/vim-surround'
  Plug 'tpope/vim-fugitive'
  Plug 'Townk/vim-autoclose'
  Plug 'tpope/vim-endwise'
"  Plug 'vim-ruby/vim-ruby'
  Plug 'skalnik/vim-vroom'
  Plug 'luochen1990/rainbow'
  Plug 'airblade/vim-gitgutter'
  Plug 'neoclide/coc.nvim', {'branch': 'release'}
  Plug 'sheerun/vim-polyglot'
  Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
  Plug 'vim-crystal/vim-crystal'
  " Plug 'pangloss/vim-javascript'
  " Plug 'mxw/vim-jsx'


"  " Future LSP support for neovim
"" Plug 'neovim/nvim-lspconfig'
"" Plug 'hrsh7th/nvim-compe'
let g:jsx_ext_required = 0

call plug#end()

let g:ale_linters = {
\   'markdown':      ['mdl', 'writegood'],
\   'ruby':      ['rubocop'],
\}
let g:ale_sign_error = '●'
let g:ale_sign_warning = '.'
"let g:ale_sign_error                  = '✘'
"let g:ale_sign_warning                = '⚠'
highlight ALEErrorSign ctermbg        =NONE ctermfg=red
highlight ALEWarningSign ctermbg      =NONE ctermfg=yellow
"============= Color Scheme and Lightline ==============
colorscheme nord

let g:lightline = {
      \ 'colorscheme': 'nord',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ],
      \             [ 'gitbranch', 'readonly', 'filename', 'modified' ] ]
      \ },
      \ 'component_function': {
      \   'gitbranch': 'gitbranch#name'
      \ },
      \ }

""============= gitgutter settings ==============
let g:gitgutter_sign_column_always = 1


""============= Nerdtree Settings ==============
let g:NERDTreeShowHidden = 1
let g:NERDTreeMinimalUI = 1
let g:NERDTreeIgnore = []
let g:NERDTreeStatusline = ''

let g:NERDTreeGitStatusIndicatorMapCustom = {
                \ 'Modified'  :'✹',
                \ 'Staged'    :'✚',
                \ 'Untracked' :'✭',
                \ 'Renamed'   :'➜',
                \ 'Unmerged'  :'═',
                \ 'Deleted'   :'✖',
                \ 'Dirty'     :'✗',
                \ 'Ignored'   :'☒',
                \ 'Clean'     :'✔︎',
                \ 'Unknown'   :'?',
                \ }

" Automatically close nvim if NERDTree is only thing left open
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" Toggle
nnoremap <silent> <C-p> :NERDTreeToggle<CR>

"============= Rainbow Settings ==============

let g:rainbow_active = 1
let g:rainbow_conf = {
	\	'separately': {
	\		'nerdtree': 0,
	\	}
	\}

""============= keybinding remaps ==============
imap jj <Esc>
nnoremap <Tab> :tabnext<CR>

let mapleader = " "
" Disable spell checking
map <leader>S :setlocal spell!<CR>
map <leader>c gcc

" Disable arrow keys
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>

" shortcuts for navigation
map <C-h> <C-w>h
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-l> <C-w>l

" split navigation
map <leader>s <C-w>s
map <leader>v <C-w>v

" save and quitting files
map <leader>w :w<CR>
map <leader>q :q<CR>
map <leader>Q :wqa<CR>
map <leader>! :qa!<CR>

" search and replace
map <leader>r :%s///g
map <leader>t :tabnew<CR>

" which key
nnoremap <silent> <leader> :WhichKey " "<CR>
" nnoremap <silent> <Space> :call VSCodeNotify('whichkey.show')<CR>

""============= Vim Settings ==============
syntax on
set number relativenumber
set noswapfile
set hlsearch
set scrolloff=10
set confirm
set spell
"" set guicursor=n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20
set ignorecase
set smartcase
set incsearch
set showmatch
set cursorline
set autoindent
set smartindent
set smarttab
set expandtab
set ruler
set tabstop=2 shiftwidth=2
set softtabstop=2
highlight LineNr ctermfg=white
autocmd BufWritePre * :%s/\s\+$//e

