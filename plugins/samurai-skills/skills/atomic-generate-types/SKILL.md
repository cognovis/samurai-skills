---
name: atomic-generate-types
description: Generate or update FHIR types using @atomic-ehr/codegen with tree-shaking — supports TypeScript, Python, and C#
---

# FHIR Type Generation with @atomic-ehr/codegen

Generate type-safe FHIR types from StructureDefinitions. Supports **TypeScript**, **Python**, and **C#**. Uses tree-shaking to only include the resource types you need.

> **Language detection:** Before setup, detect the project language from existing files (e.g., `tsconfig.json` → TypeScript, `pyproject.toml`/`requirements.txt` → Python, `*.csproj`/`*.sln` → C#). Use the matching language section below.

---

## Setup (if not already configured)

### 1. Install the codegen package

The generation script is always written in TypeScript and executed with `bun`, `tsx` (installed via `npm`, `pnpm` or `yarn`). Install the codegen package in your project (or in a separate scripts directory for non-JS projects):

```sh
# npm
npm install -D @atomic-ehr/codegen

# pnpm
pnpm add -D @atomic-ehr/codegen

# yarn
yarn add -D @atomic-ehr/codegen

# bun
bun add -d @atomic-ehr/codegen
```

For npm/pnpm/yarn projects, also install `tsx` to run the generation script:

```sh
npm install -D tsx
```

### 2. Create the generation script

Create `scripts/generate-types.ts` using the template for your target language:

#### TypeScript

```ts
import { APIBuilder, prettyReport } from "@atomic-ehr/codegen";

const builder = new APIBuilder()
  .throwException()
  .fromPackage("hl7.fhir.r4.core", "4.0.1")
  .typescript({
    withDebugComment: false,
    generateProfile: false,
    openResourceTypeSet: false,
  })
  .typeSchema({
    treeShake: {
      "hl7.fhir.r4.core": {
        // Add the resource types you need here.
        // All dependency types (Identifier, Reference, CodeableConcept, etc.)
        // are included automatically.
        "http://hl7.org/fhir/StructureDefinition/Patient": {},
        "http://hl7.org/fhir/StructureDefinition/Bundle": {},
        "http://hl7.org/fhir/StructureDefinition/OperationOutcome": {},
      },
    },
  })
  .outputTo("./src/fhir-types")
  .cleanOutput(true);

const report = await builder.generate();
console.log(prettyReport(report));
if (!report.success) process.exit(1);
```

#### Python

```ts
import { APIBuilder, prettyReport } from "@atomic-ehr/codegen";

const builder = new APIBuilder()
  .throwException()
  .fromPackage("hl7.fhir.r4.core", "4.0.1")
  .python({
    rootPackageName: "fhir_types",
    fieldFormat: "snake_case",
    allowExtraFields: false,
    fhirpyClient: false,
  })
  .typeSchema({
    treeShake: {
      "hl7.fhir.r4.core": {
        // Add the resource types you need here.
        // All dependency types are included automatically.
        "http://hl7.org/fhir/StructureDefinition/Patient": {},
        "http://hl7.org/fhir/StructureDefinition/Bundle": {},
        "http://hl7.org/fhir/StructureDefinition/OperationOutcome": {},
      },
    },
  })
  .outputTo("./fhir_types")
  .cleanOutput(true);

const report = await builder.generate();
console.log(prettyReport(report));
if (!report.success) process.exit(1);
```

#### C\#

```ts
import { APIBuilder, prettyReport } from "@atomic-ehr/codegen";

const builder = new APIBuilder()
  .throwException()
  .fromPackage("hl7.fhir.r4.core", "4.0.1")
  .csharp({
    rootNamespace: "Fhir.Types",
  })
  .typeSchema({
    treeShake: {
      "hl7.fhir.r4.core": {
        // Add the resource types you need here.
        // All dependency types are included automatically.
        "http://hl7.org/fhir/StructureDefinition/Patient": {},
        "http://hl7.org/fhir/StructureDefinition/Bundle": {},
        "http://hl7.org/fhir/StructureDefinition/OperationOutcome": {},
      },
    },
  })
  .outputTo("./FhirTypes")
  .cleanOutput(true);

const report = await builder.generate();
console.log(prettyReport(report));
if (!report.success) process.exit(1);
```

### 3. Add the script to package.json

```json
{
  "scripts": {
    "generate-types": "bun run scripts/generate-types.ts"
  }
}
```

For npm/pnpm/yarn projects (using tsx instead of bun):

```json
{
  "scripts": {
    "generate-types": "tsx scripts/generate-types.ts"
  }
}
```

### 4. Add to .gitignore

```
.codegen-cache/
```

### 5. Additional setup per language

**TypeScript** — ensure `tsconfig.json` has the required compiler options for generated imports:

```json
{
  "compilerOptions": {
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true
  }
}
```

**Python** — the generator creates a `requirements.txt` inside the output directory listing `pydantic>=2.11.0` and other deps. Install them:

```sh
pip install pydantic>=2.11.0
```

For mypy support, add the Pydantic plugin to `mypy.ini`:

```ini
[mypy]
plugins = pydantic.mypy
```

**C#** — no additional setup needed. Generated files include `Usings.cs` with necessary `using` statements.

### 6. Run generation

```sh
# bun
bun run generate-types

# npm
npm run generate-types

# pnpm
pnpm run generate-types
```

Commit the generated files — they are the project's FHIR type definitions.

---

## APIBuilder reference

### Loading FHIR packages

> **Important:** Only load packages that the user explicitly requires. Avoid adding unnecessary packages — especially core packages, which should be pulled in as dependencies of the user's IG rather than loaded directly.

```ts
// FHIR R4 base
.fromPackage("hl7.fhir.r4.core", "4.0.1")

// Implementation Guides (optional) — load from tgz URL
.fromPackageRef("https://fs.get-ig.org/-/hl7.fhir.us.core-7.0.0.tgz")
.fromPackageRef("https://fs.get-ig.org/-/fhir.r4.ukcore.stu2-2.0.2.tgz")

// Local StructureDefinition JSON files (custom resources/profiles)
.localStructureDefinitions({
  package: { name: "my-org.custom-profiles", version: "0.0.1" },
  path: "./fhir/custom-profiles",
  dependencies: [{ name: "hl7.fhir.r4.core", version: "4.0.1" }],
})

// Local tgz archive (unpublished IG built by FHIR IG Publisher)
.localTgzPackage("./fhir/my-org.custom-ig-0.1.0.tgz")
```

### Language-specific options

#### TypeScript — `.typescript()`

```ts
.typescript({
  withDebugComment: false,       // omit debug comments in generated files
  generateProfile: false,        // set true when loading IGs with constrained profiles
  openResourceTypeSet: false,    // stricter resource type unions
})
```

#### Python — `.python()`

```ts
.python({
  rootPackageName: "fhir_types",  // Python package name
  fieldFormat: "snake_case",      // "snake_case" | "PascalCase" | "camelCase"
  allowExtraFields: false,        // Pydantic model_config extra="allow"|"forbid"
  fhirpyClient: false,           // generate fhirpy-compatible base model
})
```

#### C\# — `.csharp()`

```ts
.csharp({
  rootNamespace: "Fhir.Types",   // .NET namespace for generated classes
})
```

### Tree-shaking

Tree-shaking controls which resource types are generated. Without it, ALL FHIR resources are included (~150+ files). With it, only the listed types and their transitive dependencies are generated.

```ts
.typeSchema({
  treeShake: {
    "<package-name>": {
      "<StructureDefinition canonical URL>": {},
      // ...
    },
  },
})
```

**StructureDefinition URL patterns:**

| Source | Pattern | Example |
|--------|---------|---------|
| FHIR R4 base | `http://hl7.org/fhir/StructureDefinition/{ResourceType}` | `http://hl7.org/fhir/StructureDefinition/Patient` |
| US Core | `http://hl7.org/fhir/us/core/StructureDefinition/{profile}` | `http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient` |
| UK Core | `https://fhir.hl7.org.uk/StructureDefinition/{profile}` | `https://fhir.hl7.org.uk/StructureDefinition/UKCore-Patient` |

**Common FHIR R4 resource types:**

```ts
"http://hl7.org/fhir/StructureDefinition/Patient": {},
"http://hl7.org/fhir/StructureDefinition/Encounter": {},
"http://hl7.org/fhir/StructureDefinition/Observation": {},
"http://hl7.org/fhir/StructureDefinition/Condition": {},
"http://hl7.org/fhir/StructureDefinition/Procedure": {},
"http://hl7.org/fhir/StructureDefinition/MedicationRequest": {},
"http://hl7.org/fhir/StructureDefinition/DiagnosticReport": {},
"http://hl7.org/fhir/StructureDefinition/AllergyIntolerance": {},
"http://hl7.org/fhir/StructureDefinition/Immunization": {},
"http://hl7.org/fhir/StructureDefinition/Location": {},
"http://hl7.org/fhir/StructureDefinition/Organization": {},
"http://hl7.org/fhir/StructureDefinition/Practitioner": {},
"http://hl7.org/fhir/StructureDefinition/Bundle": {},
"http://hl7.org/fhir/StructureDefinition/OperationOutcome": {},
"http://hl7.org/fhir/StructureDefinition/Questionnaire": {},
"http://hl7.org/fhir/StructureDefinition/QuestionnaireResponse": {},
```

### Output options

```ts
.outputTo("./src/fhir-types")   // output directory
.cleanOutput(true)               // delete output dir before regenerating
```

---

## What gets generated

### TypeScript

For each resource type, a `.ts` file is generated containing:

- **Main interface** — e.g., `Patient`, `Encounter`, `Bundle`
- **BackboneElement interfaces** — nested structures like `EncounterLocation`, `PatientContact`, `BundleEntry`
- **Type guard function** — e.g., `isPatient(resource)`, `isEncounter(resource)`
- **Re-exports** of dependency types (Identifier, Reference, CodeableConcept, etc.)
- **Barrel export** — `index.ts` re-exports everything for convenience

Generated types include FHIR value set enums:

```ts
status: ("planned" | "arrived" | "triaged" | "in-progress" | "onleave" | "finished" | "cancelled" | "entered-in-error" | "unknown");
subject?: Reference<"Group" | "Patient">;
```

### Python

For each resource type, a `.py` file is generated containing:

- **Pydantic BaseModel class** — e.g., `Patient(DomainResource)`, `Encounter(DomainResource)`
- **Nested backbone classes** — e.g., `EncounterLocation`, `PatientContact`
- **Literal types for closed enums** — e.g., `Literal["planned", "arrived", ...]`
- **Field aliases** for JSON round-tripping — `Field(alias="originalName", serialization_alias="originalName")`
- **`to_json()` / `from_json()` methods** on each resource
- **`__init__.py`** barrel with `model_rebuild()` calls for forward-reference resolution
- **`resource_families.py`** — runtime polymorphic validators
- **`requirements.txt`** — `pydantic>=2.11.0` and other deps

FHIR primitive type mapping: `boolean` → `bool`, `decimal` → `float`, `integer` → `int`, string-like → `str`.

### C\#

For each resource type, a `.cs` file is generated containing:

- **Public class** — e.g., `Patient : DomainResource`
- **Nested backbone classes** within the parent class
- **Nullable properties** for optional fields — `public string? Id { get; set; }`
- **Enum definitions** with `[Description("value")]` attributes in `*Enums.cs`
- **`ResourceDictionary.cs`** — `Dictionary<Type, string>` mapping types to FHIR resource names
- **`Helper.cs`** — JSON serializer options (camelCase, null-ignoring)
- **`Client.cs`** — FHIR REST client with `Search<T>`, `Read<T>`, `Create<T>`, `Update<T>`, `Delete<T>`
- **`Usings.cs`** — global using statements

FHIR primitive type mapping: `boolean` → `bool`, `decimal` → `decimal`, `integer` → `int`, `unsignedInt`/`positiveInt` → `long`, string-like → `string`.

---

## Custom resources and profiles

You can generate types for custom FHIR resources or profiles that are not part of a published IG. Place your StructureDefinition JSON files in a local folder and load them with `.localStructureDefinitions()`.

### Loading local StructureDefinitions

```ts
import { APIBuilder, prettyReport } from "@atomic-ehr/codegen";

const builder = new APIBuilder()
  .throwException()
  .fromPackage("hl7.fhir.r4.core", "4.0.1")
  .localStructureDefinitions({
    package: { name: "my-org.custom-profiles", version: "0.0.1" },
    path: "./fhir/custom-profiles",   // folder containing StructureDefinition JSON files
    dependencies: [{ name: "hl7.fhir.r4.core", version: "4.0.1" }],
  })
  .typescript({                       // or .python() / .csharp()
    withDebugComment: false,
    generateProfile: true,            // enable for custom profiles
    openResourceTypeSet: false,
  })
  .typeSchema({
    treeShake: {
      "hl7.fhir.r4.core": {
        "http://hl7.org/fhir/StructureDefinition/Bundle": {},
        "http://hl7.org/fhir/StructureDefinition/OperationOutcome": {},
      },
      "my-org.custom-profiles": {
        "http://my-org.example.com/StructureDefinition/MyCustomPatient": {},
        "http://my-org.example.com/StructureDefinition/CustomObservation": {},
      },
    },
  })
  .outputTo("./src/fhir-types")
  .cleanOutput(true);

const report = await builder.generate();
console.log(prettyReport(report));
if (!report.success) process.exit(1);
```

### Folder structure for custom profiles

```
fhir/custom-profiles/
  StructureDefinition-MyCustomPatient.json
  StructureDefinition-CustomObservation.json
```

Each file must be a valid FHIR StructureDefinition JSON resource. The canonical URL in each file (e.g., `"url": "http://my-org.example.com/StructureDefinition/MyCustomPatient"`) is what you reference in the `treeShake` config.

### Loading a local tgz package

If you have an unpublished IG built by the FHIR IG Publisher (produces a `.tgz` archive), load it directly:

```ts
.localTgzPackage("./fhir/my-org.custom-ig-0.1.0.tgz")
```

This works the same as `.fromPackageRef()` but for local archives.

---

## Example: Adding an Implementation Guide

To generate US Core profiled types alongside base R4 (TypeScript example — replace `.typescript()` with `.python()` or `.csharp()` for other languages):

```ts
import { APIBuilder, prettyReport } from "@atomic-ehr/codegen";

const builder = new APIBuilder()
  .throwException()
  .fromPackage("hl7.fhir.r4.core", "4.0.1")
  .fromPackageRef("https://fs.get-ig.org/-/hl7.fhir.us.core-7.0.0.tgz")
  .typescript({
    withDebugComment: false,
    generateProfile: true,        // enable for IG profiles
    openResourceTypeSet: false,
  })
  .typeSchema({
    treeShake: {
      "hl7.fhir.r4.core": {
        "http://hl7.org/fhir/StructureDefinition/Bundle": {},
        "http://hl7.org/fhir/StructureDefinition/OperationOutcome": {},
      },
      "hl7.fhir.us.core": {
        "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient": {},
        "http://hl7.org/fhir/us/core/StructureDefinition/us-core-condition-encounter-diagnosis": {},
        "http://hl7.org/fhir/us/core/StructureDefinition/us-core-observation-lab": {},
      },
    },
  })
  .outputTo("./src/fhir-types")
  .cleanOutput(true);

const report = await builder.generate();
console.log(prettyReport(report));
if (!report.success) process.exit(1);
```

---

## Import patterns

### TypeScript

```ts
// Direct file import (preferred — explicit about what you use)
import type { Patient } from "./fhir-types/hl7-fhir-r4-core/Patient";
import type { Encounter, EncounterLocation } from "./fhir-types/hl7-fhir-r4-core/Encounter";
import type { Bundle, BundleEntry } from "./fhir-types/hl7-fhir-r4-core/Bundle";

// Barrel import (convenient for grabbing many types)
import type { Patient, Encounter, Location, Bundle } from "./fhir-types/hl7-fhir-r4-core";

// Type guards (value imports, not type-only)
import { isPatient, isEncounter } from "./fhir-types/hl7-fhir-r4-core";
```

### Python

```python
# Direct import
from fhir_types.hl7_fhir_r4_core.patient import Patient
from fhir_types.hl7_fhir_r4_core.encounter import Encounter, EncounterLocation
from fhir_types.hl7_fhir_r4_core.bundle import Bundle, BundleEntry

# Package import
from fhir_types.hl7_fhir_r4_core import Patient, Encounter, Bundle
```

### C\#

```csharp
using Fhir.Types;
using Fhir.Types.Hl7FhirR4Core;

var patient = new Patient { /* ... */ };
var encounter = new Encounter { /* ... */ };
```

---

## Workflow for adding a new resource type

1. Edit `scripts/generate-types.ts` — add the StructureDefinition URL to `treeShake`
2. Run `npm run generate-types` (or `bun run generate-types`, `pnpm run generate-types`)
3. Import the new type in your code
4. Run typecheck / linter to verify
5. Commit the updated generated types directory
