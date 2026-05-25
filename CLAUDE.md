# samurai-skills

Claude Code plugin marketplace by Health Samurai. Contains skills for Aidbox, FHIR, and Health Samurai products.

## Structure

This repo is a **marketplace** (`.claude-plugin/marketplace.json`) containing individual plugins (one per skill) and a bundled plugin (`samurai-skills`) that includes all skills.

```
.claude-plugin/marketplace.json        — marketplace catalog
plugins/
├── samurai-skills/                    — bundled plugin (all skills)
│   ├── .claude-plugin/plugin.json
│   └── skills/
├── aidbox/                            — individual plugin
│   ├── .claude-plugin/plugin.json
│   └── skills/aidbox/SKILL.md
├── aidbox-sql-on-fhir/
│   ├── .claude-plugin/plugin.json
│   └── skills/aidbox-sql-on-fhir/SKILL.md
├── atomic-generate-types/
│   ├── .claude-plugin/plugin.json
│   └── skills/atomic-generate-types/SKILL.md
├── aidbox-ig-development/
│   ├── .claude-plugin/plugin.json
│   └── skills/aidbox-ig-development/SKILL.md
└── hs-search/
    ├── .claude-plugin/plugin.json
    └── skills/hs-search/SKILL.md
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

Run the vendor guard before pushing public skill changes:

```bash
bash scripts/vendor-leak-guard.sh
```

## Installation (for users)

```bash
# Add the marketplace
claude plugin marketplace add HealthSamurai/samurai-skills

# Install all skills at once
claude plugin install samurai-skills@samurai-skills

# Or install individual skills
claude plugin install aidbox@samurai-skills
claude plugin install aidbox-sql-on-fhir@samurai-skills
claude plugin install atomic-generate-types@samurai-skills
claude plugin install aidbox-ig-development@samurai-skills
claude plugin install hs-search@samurai-skills
```

`fhir-validation` is available through the bundled `samurai-skills` plugin and
through `npx skills add HealthSamurai/samurai-skills --skill fhir-validation`.
