import { expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

// A small closio-agent folder for the tests: three commands, two repos, a card folder and a run branch, card files,
// memory entries. Paths are matched by their end, so the folder the tests run in doesn't matter.
const SKILLS: Record<string, string> = {
  'flow-setup-repo': [
    '---', 'name: flow-setup-repo', '---', '', '## Usage', '',
    '- `/flow-setup-repo`: each repo.',
    '- `/flow-setup-repo <repo-name>`: one repo.',
    '- `/flow-setup-repo all`: every repo.',
    '- `/flow-setup-repo <repo-name|all> install`: reinstall.',
    '- `/flow-setup-repo <repo-name|all> services`: services.',
    '- `/flow-setup-repo <repo-name> dev-address <url>`: dev address.',
    '- Codex: `$flow-setup-repo …`', '', '## Steps', '- `/flow-setup-repo wrong`: not in the Usage block.',
  ].join('\n'),
  'flow-verify': [
    '## Usage', '',
    '- `/flow-verify SCRUM-567`: check.',
    '- `/flow-verify SCRUM-567 full`: A.',
    '- `/flow-verify SCRUM-567 quick`: B.',
    '- `/flow-verify SCRUM-567 full <export.xlsx>`: A with QMetry.',
  ].join('\n'),
  'flow-configure-user': [
    '## Usage', '',
    '- `/flow-configure-user`: everything.',
    '- `/flow-configure-user <item>`: one item, e.g. `/flow-configure-user gitlab-token`. Items: `gitlab-token`, `git-name`, `playwright`.',
  ].join('\n'),
  'flow-configure-repo': [
    '## Usage', '',
    '- `/flow-configure-repo <repo-name>`: a repo.',
    '- `/flow-configure-repo <full path of a local clone>`: register.',
    '- `/flow-configure-repo <repo-name> key <name>`: one key.',
    '- `/flow-configure-repo <repo-name> path <full path | not-cloned>`: the path.',
  ].join('\n'),
  'flow-memory': [
    '## Usage', '',
    '- `/flow-memory add <text>`: general.',
    '- `/flow-memory add <repo> <text>`: a repo.',
    '- `/flow-memory edit <id> phases <phases>`: phases.',
    '- `/flow-memory remove <id>`: remove.',
  ].join('\n'),
  'flow-check-card': ['## Usage', '', '- `/flow-check-card SCRUM-567`: from Jira.', '- `/flow-check-card local/cards/my-draft.md`: a file.'].join('\n'),
  'flow-help': ['## Usage', '', '- `/flow-help <command>`: one command.'].join('\n'),
}

const dir = (name: string) => ({ name, kind: 'dir' as const, size: 0, mtimeMs: 0, isLink: false })
const file = (name: string) => ({ name, kind: 'file' as const, size: 1, mtimeMs: 0, isLink: false })

const FOLDERS: Record<string, ReturnType<typeof file>[]> = {
  '/config/repos': [file('nodejs-ws1closio.yaml'), file('ws2jauth.yaml'), file('README.md')],
  '/runs': [dir('SCRUM-523'), dir('notes')],
  '/.agents/skills': [dir('flow-help'), dir('flow-memory'), dir('flow-verify'), file('README.md')],
  '/local/cards': [file('SCRUM-559.md'), file('draft.md'), file('notes.txt')],
  '/local/memory': [file('general.md'), dir('repos')],
  '/local/memory/repos': [file('ws2jauth.md')],
}
const FILES: Record<string, string> = {
  '/config/repos/nodejs-ws1closio.yaml': 'name: nodejs-ws1closio\ndev_keys: ws1-client-id, ws1-client-secret   # WS1 sends these\n',
  '/config/repos/ws2jauth.yaml': 'name: ws2jauth\ndev_keys: none\ndev_keys_optional: db-user\n',
  '/local/memory/general.md': '- [M1] 2026-10-16 · phases: all · from: - · One.\nnot an entry\n- [M4] 2026-10-17 · phases: plan · from: - · Two.\n',
  '/local/memory/repos/ws2jauth.md': '- [M7] 2026-10-18 · phases: develop · from: - · Three.\n',
  '/scripts/memory.sh': 'set -u\nPHASES="all setup plan develop"\n',
}

const project = (on: On) => {
  on('prompt.autocomplete', () => ({ suggestions: [] }))
  on('fs.read', ($, e) => {
    const skill = /\/\.agents\/skills\/([^/]+)\/SKILL\.md$/.exec(e.path)?.[1]
    if (skill !== undefined && SKILLS[skill] !== undefined) return { value: SKILLS[skill] }
    const known = Object.keys(FILES).find(end => e.path.endsWith(end))
    if (known !== undefined) return { value: FILES[known] }
    return { deny: `no such file in the test: ${e.path}` }
  })
  on('fs.list', ($, e) => {
    const known = Object.keys(FOLDERS).find(end => e.path.endsWith(end))
    return known !== undefined ? { value: FOLDERS[known] } : { deny: `no such folder in the test: ${e.path}` }
  })
  // git for-each-ref, answered the way git does: every ref under the asked prefix, with as many leading parts
  // stripped as the format's lstrip asks (refs/remotes/origin/runs/SCRUM-540 with lstrip=4 is SCRUM-540).
  on('process.run', ($, e) => {
    const strip = Number(/lstrip=(\d+)/.exec(e.argv.join(' '))?.[1] ?? 0)
    const prefix = e.argv[e.argv.length - 1]
    const refs = ['refs/remotes/origin/runs/SCRUM-540', 'refs/remotes/origin/runs/not-a-card']
    const stdout = refs.filter(ref => ref.startsWith(prefix)).map(ref => ref.split('/').slice(strip).join('/')).join('\n')
    return { value: { exitCode: 0, stdout: `${stdout}\n`, stderr: '' } }
  })
}

// The prompt box with the caret at the end: the token is the last run of non-spaces.
const typing = (text: string) => {
  const start = text.search(/\S+$/)
  return { text, cursor: text.length, token: text.slice(start), start }
}
const suggest = async ($: Parameters<Parameters<typeof test>[1]>[0], text: string) =>
  (await $.prompt.autocomplete(typing(text))).suggestions.map(row => row.text)

test('repos and all, for the first word', async ($, on) => {
  project(on)
  expect(await suggest($, '/flow-setup-repo n')).toEqual(['nodejs-ws1closio'])
  expect(await suggest($, '/flow-setup-repo a')).toEqual(['all'])
})

test('the options after a repo, only from the Usage block', async ($, on) => {
  project(on)
  expect(await suggest($, '/flow-setup-repo ws2jauth s')).toEqual(['services'])
  expect(await suggest($, '/flow-setup-repo all i')).toEqual(['install'])
  expect(await suggest($, '/flow-setup-repo ws2jauth w')).toEqual([])
})

test('card keys from runs/ and the run branches, then the options', async ($, on) => {
  project(on)
  expect(await suggest($, '/flow-verify s')).toEqual(['SCRUM-523', 'SCRUM-540'])
  expect(await suggest($, '/flow-verify SCRUM-540 q')).toEqual(['quick'])
})

test('the items of flow-configure-user, from its Usage line', async ($, on) => {
  project(on)
  expect(await suggest($, '/flow-configure-user git')).toEqual(['gitlab-token', 'git-name'])
})

test('a repo, its options, its dev keys and not-cloned for flow-configure-repo', async ($, on) => {
  project(on)
  expect(await suggest($, '/flow-configure-repo nodejs-ws1closio k')).toEqual(['key'])
  expect(await suggest($, '/flow-configure-repo nodejs-ws1closio key w')).toEqual(['ws1-client-id', 'ws1-client-secret'])
  expect(await suggest($, '/flow-configure-repo ws2jauth key d')).toEqual(['db-user'])
  expect(await suggest($, '/flow-configure-repo ws2jauth path n')).toEqual(['not-cloned'])
})

test('memory: a repo after add, the entry ids, the phases after a comma', async ($, on) => {
  project(on)
  expect(await suggest($, '/flow-memory add w')).toEqual(['ws2jauth'])
  expect(await suggest($, '/flow-memory remove M')).toEqual(['M1', 'M4', 'M7'])
  expect(await suggest($, '/flow-memory edit M4 phases plan,d')).toEqual(['plan,develop'])
})

test('card files like the example, and command names', async ($, on) => {
  project(on)
  expect(await suggest($, '/flow-check-card l')).toEqual(['local/cards/SCRUM-559.md', 'local/cards/draft.md'])
  expect(await suggest($, '/flow-help m')).toEqual(['memory'])
})

test('nothing for the command name itself, an unknown command or another prompt', async ($, on) => {
  project(on)
  expect(await suggest($, '/flow-setu')).toEqual([])
  expect(await suggest($, '/flow-nothere a')).toEqual([])
  expect(await suggest($, 'please check n')).toEqual([])
})
