# Health Samurai Skills

Claude Code plugin with skills for Health Samurai products and healthcare development.

## Installation

Add the marketplace:

```bash
claude plugin marketplace add HealthSamurai/samurai-skills
```

Install all skills at once:

```bash
claude plugin install samurai-skills@samurai-skills
```

Or install individual skills:

```bash
claude plugin install aidbox@samurai-skills
claude plugin install aidbox-sql-on-fhir@samurai-skills
claude plugin install atomic-generate-types@samurai-skills
claude plugin install hs-search@samurai-skills
```

## Skills

| Skill | Description |
|-------|-------------|
| `aidbox` | Aidbox FHIR platform — API, configuration, access control, terminology |
| `aidbox-sql-on-fhir` | SQL on FHIR with Aidbox — ViewDefinitions, $materialize, sof schema |
| `atomic-generate-types` | Generate FHIR types using @atomic-ehr/codegen — TypeScript, Python, C# |
| `hs-search` | Search health-samurai.io — docs, blog, case studies, examples |

## Creating a new skill

Use `template/SKILL.md` as a starting point. Each skill is a folder under `plugins/samurai-skills/skills/` with a `SKILL.md` file. See [Skills docs](https://code.claude.com/docs/en/skills) for the frontmatter format.

## Structure

```
.claude-plugin/
└── marketplace.json                    # Marketplace catalog
plugins/
└── samurai-skills/                     # Plugin
    ├── .claude-plugin/
    │   └── plugin.json                 # Plugin manifest
    └── skills/
        ├── aidbox/SKILL.md
        ├── aidbox-sql-on-fhir/SKILL.md
        ├── atomic-generate-types/SKILL.md
        └── hs-search/SKILL.md
template/
└── SKILL.md                            # Template for new skills
```
