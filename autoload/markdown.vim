" File: autoload/markdown.vim
" Author: David Granström
" Description: Preview markdown files in the browser
" License: GPL3

let s:script_path = expand('<sfile>:p:h:h')
let s:css_path = s:script_path . '/css/'
let s:highlight_path = s:script_path . '/highlight/'

let s:Pandoc = {'name': 'Pandoc'}
let s:output_path = tempname() . '.html'

function! s:interpolate(str, tvars)
  let ss = a:str
  for key in keys(a:tvars)
    let kvar = '${' . key . '}'
    let idx = stridx(ss, kvar)

    if idx > -1
      let prefix = ''
      if idx > 0 " Silly vimscript >:/
        let prefix = ss[:idx-1]
      endif
      let ss = prefix . a:tvars[key] . ss[idx+len(kvar):]
    endif
  endfor
  return ss
endfunction

function! s:Pandoc.generate(theme, restart) abort
  let input_path = expand('%:p')
  let filename = expand('%:r')
  let stylesheet = s:css_path . a:theme . '.css'
  let highlight = s:highlight_path . a:theme . '.theme'
  let input_format = get(g:, 'nvim_markdown_preview_format', 'gfm')
  let cmd = get(g:, 'nvim_markdown_preview_convert_command', [])

  let self.server_index_path = s:output_path
  let self.server_root = fnamemodify(input_path, ':h')

  if filereadable(input_path)
    if a:restart > 0
      call s:LiveServer.stop()
    endif
    if l:cmd ==# []
      let cmd = ['pandoc',
            \ '-f', '${INPUT_FORMAT}',
            \ '${INPUT_PATH}',
            \ '-o', '${OUTPUT_PATH}',
            \ '--standalone',
            \ '-t', 'html',
            \ '--katex',
            \ '--highlight-style=${HIGHLIGHT}',
            \ '--metadata', 'pagetitle=${FILENAME}',
            \ '--include-in-header=${STYLESHEET}',
            \ ]
    endif

    let tvars = {
          \ 'INPUT_FORMAT': l:input_format,
          \ 'INPUT_PATH': l:input_path,
          \ 'FILENAME': l:filename,
          \ 'OUTPUT_PATH': s:output_path,
          \ 'HIGHLIGHT': l:highlight,
          \ 'STYLESHEET': l:stylesheet,
          \ }
    call jobstart(map(cmd, {_, x -> s:interpolate(x, tvars)}), self)
  endif
endfunction

function! s:Pandoc.on_exit(job_id, data, event)
  call s:LiveServer.start(self.server_root, self.server_index_path)
endfunction

function! s:Pandoc.on_stderr(job_id, data, event)
  let msg = join(a:data)
  if !empty(msg)
    echoerr printf('[%s] %s', self.name, join(a:data))
  endif
endfunction

let s:LiveServer = {'name': 'LiveServer'}

function! s:LiveServer.start(root, index_path)
  if !exists('self.pid')
    let mount_path = fnamemodify(a:index_path, ':h')
    let index = fnamemodify(a:index_path, ':t')
    let extra_opts = get(g:, 'nvim_markdown_preview_liveserver_extra_args', [])
    let self.pid = jobstart([
          \ 'live-server',
          \ '--quiet',
          \ '--mount='.'/:'.mount_path,
          \ '--open='.index,
          \ ] + extra_opts + [a:root],
          \ self,
          \ )
  endif
endfunction

function! s:LiveServer.stop()
  if exists('self.pid')
    call jobstop(self.pid)
    unlet self.pid
  endif
endfunction

function! s:LiveServer.on_stderr(job_id, data, event)
  let msg = join(a:data)
  if !empty(msg)
    echoerr printf('[%s] %s', self.name, msg)
  endif
endfunction

" Interface

function! markdown#generate(theme, restart) abort
  call s:Pandoc.generate(a:theme, a:restart)
endfunction

function! markdown#server_start(file) abort
  call s:LiveServer.start(a:file)
endfunction

function! markdown#server_stop() abort
  call s:LiveServer.stop()
endfunction
