# samurai-skills

Claude Code plugin marketplace by Health Samurai. Contains skills for Aidbox, FHIR, and Health Samurai products.

## Structure

This repo is a **marketplace** (`.claude-plugin/marketplace.json`) containing one **plugin** (`plugins/samurai-skills/`) with multiple skills inside.

```
.claude-plugin/marketplace.json        — marketplace catalog
plugins/samurai-skills/
├── .claude-plugin/plugin.json         — plugin manifest (name, version)
└── skills/                            — auto-discovered by Claude Code
    ├── aidbox/SKILL.md
    ├── aidbox-sql-on-fhir/SKILL.md
    ├── atomic-generate-types/SKILL.md
    └── hs-search/SKILL.md
```

## Version bumps

After changing any SKILL.md, bump `version` in `plugins/samurai-skills/.claude-plugin/plugin.json`. Claude Code uses the version to detect updates — without a bump, users won't see changes due to caching.

## Adding a new skill

1. Create `plugins/samurai-skills/skills/<skill-name>/SKILL.md` with frontmatter (`name`, `description`) and instructions
2. Use `template/SKILL.md` as a starting point
3. Bump plugin version in `plugins/samurai-skills/.claude-plugin/plugin.json`
4. Skills are auto-discovered from `skills/` — no need to register them anywhere

## Testing locally

```bash
claude --plugin-dir ./plugins/samurai-skills
```

Then invoke with `/samurai-skills:<skill-name>`.

## Installation (for users)

```bash
claude plugin marketplace add HealthSamurai/samurai-skills
claude plugin install samurai-skills@samurai-skills
```
