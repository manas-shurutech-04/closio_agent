import type { EngineInterface, Register } from 'claude-code'

// flow-autocomplete (closio-agent): suggests the options of a flow command while you type it in Claude Code, in every
// session started in the closio-agent folder (the terminal and the desktop app's chat). It keeps nothing: each time
// the prompt box asks, it reads the project, so a new command, option, repo or card shows at once.
//   - a command's options: its own "## Usage" block (.agents/skills/<command>/SKILL.md), form by form;
//   - <repo>, <repo-name>: config/repos/*.yaml · a card key (SCRUM-567): runs/ and the run branches (origin/runs/…);
//   - <item>: the "Items:" list on that Usage line · <command>: .agents/skills/flow-* · <id>: local/memory/ entries;
//   - <phases>: PHASES in scripts/memory.sh · key <name>: the repo file's dev_keys · a file like local/cards/x.md:
//     the files in that folder.
// Claude Code asks once a letter of the option is typed (never right after a space). Codex has nothing like this.

type Engine = EngineInterface

// Words in a Usage form: a <placeholder> (spaces allowed), a "quoted example", or a plain word.
const FORM_WORDS = /<[^>]*>|"[^"]*"|\S+/g
const CARD_KEY = /^[A-Z][A-Z0-9]*-\d+$/
const PLAIN_WORD = /^[a-z][a-z0-9-]*$/

const project = ($: Engine) => `${$.plugin.root}/../../..`
const listNames = ($: Engine, path: string) => $.fs.list(path).catch(() => [])
const readText = async ($: Engine, path: string) => {
  const text = await $.fs.read(path).catch(() => '')
  return typeof text === 'string' ? text : ''
}

// The Usage lines of a command ("- `/flow-x …`: …", not the Codex line), each with its form's words after the name.
const usageForms = async ($: Engine, command: string) => {
  const skill = await readText($, `${project($)}/.agents/skills/${command}/SKILL.md`)
  const block = skill.split(/^## Usage[ \t]*$/m)[1]?.split(/^## /m)[0] ?? ''
  return block
    .split('\n')
    .filter(line => line.startsWith('- `/'))
    .map(line => {
      const form = /^- `([^`]*)`/.exec(line)?.[1] ?? ''
      return { line, words: (form.match(FORM_WORDS) ?? []).slice(1) }
    })
}

// Does a typed word fit a form word? A literal must be typed as it is; a placeholder or an example takes any word.
const fits = (formWord: string, typed: string) =>
  formWord.startsWith('<') || formWord.startsWith('"') || CARD_KEY.test(formWord) || /^\d+$/.test(formWord) ||
  formWord.includes('/') || formWord === typed

const repos = async ($: Engine) =>
  (await listNames($, `${project($)}/config/repos`))
    .filter(entry => entry.kind === 'file' && entry.name.endsWith('.yaml'))
    .map(entry => entry.name.slice(0, -'.yaml'.length))

const cards = async ($: Engine) => {
  const folders = (await listNames($, `${project($)}/runs`))
    .filter(entry => entry.kind === 'dir' && CARD_KEY.test(entry.name))
    .map(entry => entry.name)
  const branches = await $.process
    .run(['git', 'for-each-ref', '--format=%(refname:lstrip=4)', 'refs/remotes/origin/runs/'], { cwd: project($), timeoutMs: 3000 })
    .then(result => (result.exitCode === 0 ? result.stdout.split('\n').filter(key => CARD_KEY.test(key)) : []))
    .catch(() => [] as string[])
  return [...folders, ...branches]
}

const commands = async ($: Engine) => {
  const names = (await listNames($, `${project($)}/.agents/skills`))
    .filter(entry => entry.kind === 'dir' && entry.name.startsWith('flow-'))
    .map(entry => entry.name)
  return [...names, ...names.map(name => name.slice('flow-'.length))]
}

const memoryIds = async ($: Engine) => {
  const dir = `${project($)}/local/memory`
  const files = [
    ...(await listNames($, dir)).filter(entry => entry.kind === 'file').map(entry => `${dir}/${entry.name}`),
    ...(await listNames($, `${dir}/repos`)).filter(entry => entry.kind === 'file').map(entry => `${dir}/repos/${entry.name}`),
  ]
  const ids: string[] = []
  for (const file of files) for (const match of (await readText($, file)).matchAll(/^- \[(M\d+)\]/gm)) ids.push(match[1])
  return ids
}

const phases = async ($: Engine, token: string) => {
  const list = /^PHASES="([^"]*)"/m.exec(await readText($, `${project($)}/scripts/memory.sh`))?.[1].split(/\s+/) ?? []
  const done = token.includes(',') ? token.slice(0, token.lastIndexOf(',') + 1) : ''
  return list.map(phase => done + phase)
}

const devKeys = async ($: Engine, repo: string) => {
  const file = await readText($, `${project($)}/config/repos/${repo}.yaml`)
  return [...file.matchAll(/^dev_keys(?:_optional)?:[ \t]*([^#\n]*)/gm)]
    .flatMap(match => match[1].split(','))
    .map(key => key.trim())
    .filter(key => key !== '' && key !== 'none')
}

const filesLike = async ($: Engine, example: string) => {
  const folder = example.slice(0, example.lastIndexOf('/'))
  const ending = /\.[a-z0-9]+$/i.exec(example)?.[0] ?? ''
  return (await listNames($, `${project($)}/${folder}`))
    .filter(entry => entry.kind === 'file' && entry.name.endsWith(ending))
    .map(entry => `${folder}/${entry.name}`)
}

// What fits in a form word's place: the words it stands for, read from the project now.
const choices = async ($: Engine, formWord: string, line: string, typed: string[], token: string): Promise<string[]> => {
  if (formWord.startsWith('"') || /^\d+$/.test(formWord)) return []
  if (CARD_KEY.test(formWord)) return cards($)
  if (formWord.includes('/')) return filesLike($, formWord)
  if (!formWord.startsWith('<')) return [formWord]
  const alternatives = formWord.slice(1, -1).split('|').map(word => word.trim())
  const found: string[] = []
  for (const word of alternatives) {
    if (word === 'repo' || word === 'repo-name') found.push(...(await repos($)))
    else if (word === 'CARD-KEY') found.push(...(await cards($)))
    else if (word === 'item') found.push(...[...(line.split('Items:')[1] ?? '').matchAll(/`([^`]+)`/g)].map(match => match[1]))
    else if (word === 'command') found.push(...(await commands($)))
    else if (word === 'id') found.push(...(await memoryIds($)))
    else if (word === 'phases') found.push(...(await phases($, token)))
    else if (word === 'name' && typed.at(-1) === 'key') found.push(...(await devKeys($, typed.at(0) ?? '')))
    else if (alternatives.length > 1 && PLAIN_WORD.test(word)) found.push(word)
  }
  return found
}

export const register: Register = on => {
  on('prompt.autocomplete', async ($, e, next) => {
    const before = await next(e)
    const typedSoFar = /^\/(flow-[a-z0-9-]+)\s+([\s\S]*)$/.exec(e.text.slice(0, e.cursor))
    if (typedSoFar === null) return before
    const [, command, rest] = typedSoFar
    const typed = rest.split(/\s+/)
    const token = typed.pop() ?? ''
    if (token !== e.token) return before

    const rows: string[] = []
    for (const form of await usageForms($, command)) {
      const formWord = form.words.at(typed.length)
      if (formWord === undefined || !typed.every((word, i) => fits(form.words.at(i) ?? '', word))) continue
      rows.push(...(await choices($, formWord, form.line, typed, token)))
    }
    const wanted = token.toLowerCase()
    const matching = [...new Set(rows)].filter(row => row.toLowerCase().startsWith(wanted) && row !== token)
    return { suggestions: [...before.suggestions, ...matching.map(text => ({ text }))] }
  })
}
