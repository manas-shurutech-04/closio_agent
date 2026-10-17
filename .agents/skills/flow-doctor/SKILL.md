---
name: flow-doctor
description: Checks that this Mac is set up correctly for the flow commands and shows how to fix each problem. Runs only when the user types /flow-doctor (Claude Code) or $flow-doctor (Codex).
disable-model-invocation: true
---

# flow-doctor

Checks the user's setup and shows how to fix each problem. It only reads; it never changes anything.

Symbols: ✅ fine, ⚠️ worth a look (doesn't fail), ❌ must fix. Every ⚠️ and ❌ comes with the steps to fix it (rule A11).

## Usage

- `/flow-doctor`: check this Mac's setup (project, tools, VPN and GitLab, personal settings, user memory, commands documented, cards in progress, repos, repo setup, Keychain names, Jira) and show how to fix each problem.
- Codex: `$flow-doctor` (approve running it with network access, so the GitLab checks can run).

## Steps

1. **User memory (rule A7), never skipped:** your memory entries for this command are loaded here automatically:

   !`bash scripts/memory.sh for setup all`

   Apply what's above: the general entries, and repo entries only for the repo(s) this command works on. Say in one line which entries you used (e.g. "Using your memory: M2, M3"); say nothing if none apply. Team rules always win (rule A8): if an entry conflicts with one, say so and follow the team rule. **If the block above still shows the command instead of its output** (e.g. in Codex, which doesn't run it by itself), run `bash scripts/memory.sh for setup all` yourself first, before anything else.
2. From the folder this session started in, run: `bash scripts/doctor.sh`
   - In Codex, ask the user to approve running it with network access, so the GitLab checks can run.
3. If `scripts/doctor.sh` isn't found, this session wasn't started in the closio-agent folder. Tell the user: "Quit, open a terminal in the closio-agent folder, run `nvm use v22`, then start Claude Code or Codex again." Stop there.
4. Show the script's output exactly as printed, except its last "Result" line.
5. **Jira check (only you can do this; the script can't):** read one thing from Jira project `SCRUM` on `productclosio.atlassian.net` with your Jira (Atlassian) tools, e.g. the project itself or one issue. Read only; never change anything in Jira. Then print a "Jira" section with one line:
   - **The Jira tools can take a while to load** at the start of a session. If you can't find them, or the tool says the Atlassian connector is still connecting: run `bash scripts/wait-seconds.sh 10`, then look for them again. Try **up to 3 times** (about 30 seconds) before reporting ❌.
   - It works: `✅ Jira works: project SCRUM can be read`
   - You have no Jira tools, or the read fails: `❌ Jira isn't connected in <Claude Code or Codex>`, followed by the fix:
     - Claude Code: `Fix: the Jira connector may still be loading or timed out. Type /mcp, choose "claude.ai Atlassian MCP", then Reconnect, and run /flow-doctor again. If it's not connected at all, connect Claude's Atlassian connector to your Atlassian account (setup guide, section 3), then start a new session.`
     - Codex: `Fix: connect the Atlassian app to the ChatGPT account you use for Codex, then start Codex again. Other way: in a terminal run 'codex mcp add atlassian --url https://mcp.atlassian.com/v2/mcp' and 'codex mcp login atlassian' (setup guide, section 3).`
6. End with two lines:
   - `Result: <N> to fix, <M> to look at.` (the script's counts plus the Jira line)
   - `Checked in <the tool you are running in: Claude Code or Codex>`

Rules:
- Run the script exactly as written here (`bash scripts/…` from the closio-agent folder, no `cd`, nothing joined with `&&`). That's how Claude Code recognises it as pre-approved (D49).
- Don't fix anything yourself. Only report.
- Never read or print secrets, `.env` files or Keychain values.
