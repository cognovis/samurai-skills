# Health Samurai Skills

Claude Code plugin with skills for Health Samurai products and healthcare development.

## Installation

Add the marketplace and install the plugin:

```bash
claude plugin marketplace add HealthSamurai/samurai-skills
claude plugin install samurai-skills@samurai-skills
```

Skills are namespaced: `/samurai-skills:aidbox`, `/samurai-skills:hs-search`, etc.

## Skills

| Skill | Description |
|-------|-------------|
| `aidbox` | Aidbox FHIR platform — API, configuration, access control, terminology |
| `aidbox-sql-on-fhir` | SQL on FHIR with Aidbox — ViewDefinitions, $materialize, sof schema |
| `atomic-generate-types` | Generate FHIR types using @atomic-ehr/codegen — TypeScript, Python, C# |
| `hs-search` | Search health-samurai.io — docs, blog, case studies, examples |

## Creating a new skill

Each skill is a folder under `skills/` with a `SKILL.md` file. See [Skills docs](https://code.claude.com/docs/en/skills) for the frontmatter format.

## Structure

```
.claude-plugin/
├── plugin.json            # Plugin manifest
└── marketplace.json       # Marketplace listing
skills/
├── aidbox/                # Aidbox FHIR platform
│   └── SKILL.md
├── aidbox-sql-on-fhir/    # SQL on FHIR ViewDefinitions & analytics
│   └── SKILL.md
├── atomic-generate-types/ # FHIR type generation
│   └── SKILL.md
└── hs-search/             # Health Samurai site search
    └── SKILL.md
```
