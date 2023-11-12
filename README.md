# Neochat

Neochat is a neovim plugin that integrates a fork of
[sigoden/aichat](https://github.com/sigoden/aichat) (an excellent CLI interface
to ChatGPT) into Neovim to Get a [cursor.sh](https://cursor.sh)-like experience.


### Features
- A full featured ChatGPT client running inside neovim, complete with syntax highlighting and streaming
- Context aware code modification - give GPT-4 instructions and let it edit your code for you
- Context aware code generation - give GPT-4 instructions and let it insert new code for you


### Status

Alpha: it works and is useful, but there is much yet to be done


## Installation 

- Using [junegunn/vim-plug](https://github.com/junegunn/vim-plug): 

  ```
  Plug 'nikvdp/neochat'
  ```

- Using [folke/lazy.nvim](https://github.com/folke/lazy.nvim) 

  ```lua
  require("lazy").setup({
    "nikvdp/neochat",
  })
  ```
- Tell Neochat your OpenAI API key via the `OPENAI_API_KEY` env var. Either set
  it before starting neovim, or do `let $OPENAI_API_KEY="sk..."` in your
  init.vim

## Usage

At the moment neochat has 3 modes:

1. Run `:Neochat` to start a new chat session (not context or codebase aware)
   to chat with ChatGPT from within neovim 
2. Run `:Neochat <some instructions>` with a visual selection to have GPT-4
   edit your code in place. 

   eg. `Neochat add comments` would have GPT-4 add comments to the visually
   selected text

3. Run `:NeochatGen <instructions>` to have GPT-4 generate code for you
   (context-aware). 

   eg. `:NeochatGen add a function to generate the fibonacci sequence`.


