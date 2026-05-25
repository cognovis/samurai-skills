---
name: aidbox-ig-development
description: >
  FHIR Implementation Guide development lifecycle with Aidbox. Use when developing, testing,
  validating, or publishing FHIR IGs — CodeSystems, ValueSets, profiles, extensions,
  terminology, IG Publisher, QA reports, SUSHI/FSH, $validate, $expand, $validate-code,
  $fhir-package-install. Triggers on mentions of "implementation guide", "IG development",
  "FHIR profile", "CodeSystem", "ValueSet", "terminology testing", "IG Publisher",
  "publish IG", "QA report", "SUSHI", "FSH", "validation".
---

# FHIR IG Development with Aidbox

Develop, test, validate, and publish FHIR Implementation Guides using Aidbox as the FHIR server.

## 1. Project Setup

### Directory Structure

A typical IG project follows this layout:

```
my-ig/
├── sushi-config.yaml          # SUSHI configuration (canonical URL, package ID, version)
├── input/
│   └── fsh/                   # FSH source files
│       ├── profiles/          # StructureDefinitions
│       ├── extensions/        # Extension definitions
│       ├── codesystems/       # CodeSystem definitions
│       ├── valuesets/         # ValueSet definitions
│       └── examples/          # Example resources
├── fsh-generated/
│   └── resources/             # SUSHI output (generated JSON)
├── input-cache/
│   └── publisher.jar          # IG Publisher JAR
├── test/                      # httpyac test files
│   ├── CS/
│   ├── VS/
│   └── Profile/
├── output/                    # IG Publisher output
└── docker-compose.yml         # Local Aidbox instance
```

Alternative layouts use `src/CS/`, `src/VS/`, `src/Profiles/` with a `target/` directory for generated JSON. Adapt paths to your project.

### Docker Compose for Local Aidbox

```bash
# Download pre-configured docker-compose.yml
curl -JO https://aidbox.app/runme

# Start Aidbox + PostgreSQL (--wait blocks until healthy)
docker compose up -d --wait
```

Default access: `http://localhost:8080` with `Basic basic:secret`.

### SUSHI / FSH Basics

```bash
# Install SUSHI globally
npm install -g fsh-sushi

# Compile FSH to FHIR JSON
sushi .

# Output lands in fsh-generated/resources/
```

## 2. IG Installation on Aidbox

### Direct API Install

Use the `$fhir-package-install` operation to load an IG package:

```bash
curl -s -u $AIDBOX_AUTH -X POST "$AIDBOX_URL/fhir/\$fhir-package-install" \
  -H "Content-Type: application/json" \
  -d '{
    "resourceType": "Parameters",
    "parameter": [{
      "name": "package",
      "valueString": "<package-id>@<version>"
    }]
  }'
```

### Local Package Install (Build + Docker Copy)

For development, build and install from local source:

```bash
# 1. Build the package (creates dist/package.tgz or similar)
sushi .
# or: bash scripts/build-package.sh

# 2. Copy into the Aidbox container
docker cp dist/package.tgz <aidbox-container>:/tmp/package.tgz

# 3. Install via API
curl -s -u $AIDBOX_AUTH -X POST "$AIDBOX_URL/fhir/\$fhir-package-install" \
  -H "Content-Type: application/json" \
  -d '{
    "resourceType": "Parameters",
    "parameter": [{
      "name": "package",
      "valueString": "file:///tmp/package.tgz"
    }]
  }'
```

### Verify Installation

```bash
# Check StructureDefinitions loaded
curl -s -u $AIDBOX_AUTH "$AIDBOX_URL/fhir/StructureDefinition?url:contains=<canonical-prefix>&_summary=count"

# Check CodeSystems loaded
curl -s -u $AIDBOX_AUTH "$AIDBOX_URL/fhir/CodeSystem?url:contains=<canonical-prefix>&_summary=count"

# Check ValueSets loaded
curl -s -u $AIDBOX_AUTH "$AIDBOX_URL/fhir/ValueSet?url:contains=<canonical-prefix>&_summary=count"
```

Replace `<canonical-prefix>` with your IG's canonical URL base.

## 3. Testing CodeSystems

### Create and Test

1. Upload the CodeSystem:

```bash
curl -s -u $AIDBOX_AUTH -X PUT "$AIDBOX_URL/fhir/CodeSystem/<id>" \
  -H "Content-Type: application/fhir+json" \
  -d @fsh-generated/resources/CodeSystem-<id>.json
```

2. Test code lookup. **Important: Aidbox does NOT implement `$lookup` on the FHIR endpoint.** Use the Aidbox-native Concept API:

```bash
# Valid code — expect entry with display and system
curl -s -u $AIDBOX_AUTH "$AIDBOX_URL/Concept?system=<codesystem-url>&code=<code>"

# Invalid code — expect empty bundle
curl -s -u $AIDBOX_AUTH "$AIDBOX_URL/Concept?system=<codesystem-url>&code=INVALID_CODE_XYZ"
```

3. Clean up:

```bash
curl -s -u $AIDBOX_AUTH -X DELETE "$AIDBOX_URL/fhir/CodeSystem/<id>"
```

### httpyac Test File Format

Save as `test/CS/<id>.http`:

```http
@fhirServer = http://localhost:8080
@aidboxServer = http://localhost:8080
@auth = Basic basic:secret

### Create CodeSystem
PUT {{fhirServer}}/fhir/CodeSystem/{{id}}
Authorization: {{auth}}
Content-Type: application/fhir+json

< ../../fsh-generated/resources/CodeSystem-{{id}}.json

### Lookup valid code (native Concept API)
GET {{aidboxServer}}/Concept?system={{systemUrl}}&code={{validCode}}
Authorization: {{auth}}

### Lookup invalid code (expect empty)
GET {{aidboxServer}}/Concept?system={{systemUrl}}&code=INVALID_CODE_XYZ
Authorization: {{auth}}

### Cleanup
DELETE {{fhirServer}}/fhir/CodeSystem/{{id}}
Authorization: {{auth}}
```

Run with:

```bash
httpyac send -a test/CS/<id>.http | tee "test/CS/<id>_run$(date +%Y%m%d%H%M%S).log"
```

## 4. Testing ValueSets

### Create Dependencies and Test

1. Upload required CodeSystems first, then the ValueSet:

```bash
# Upload referenced CodeSystem(s)
curl -s -u $AIDBOX_AUTH -X PUT "$AIDBOX_URL/fhir/CodeSystem/<cs-id>" \
  -H "Content-Type: application/fhir+json" \
  -d @fsh-generated/resources/CodeSystem-<cs-id>.json

# Upload ValueSet
curl -s -u $AIDBOX_AUTH -X PUT "$AIDBOX_URL/fhir/ValueSet/<vs-id>" \
  -H "Content-Type: application/fhir+json" \
  -d @fsh-generated/resources/ValueSet-<vs-id>.json
```

2. Test expansion. **Important: Use the Aidbox-native endpoint, not the FHIR endpoint:**

```bash
# Expand — native endpoint works reliably
curl -s -u $AIDBOX_AUTH "$AIDBOX_URL/ValueSet/<vs-id>/\$expand"
```

Verify the `expansion.contains` array includes the expected codes.

3. Validate codes:

```bash
# Valid code — expect "result": true
curl -s -u $AIDBOX_AUTH \
  "$AIDBOX_URL/fhir/ValueSet/\$validate-code?url=<valueset-url>&system=<codesystem-url>&code=<code>"

# Invalid code — expect "result": false
curl -s -u $AIDBOX_AUTH \
  "$AIDBOX_URL/fhir/ValueSet/\$validate-code?url=<valueset-url>&system=<codesystem-url>&code=INVALID_XYZ"
```

4. Clean up ValueSet and CodeSystems.

### httpyac Test File Format

Save as `test/VS/<id>.http`:

```http
@fhirServer = http://localhost:8080
@aidboxServer = http://localhost:8080
@auth = Basic basic:secret

### Create CodeSystem dependency
PUT {{fhirServer}}/fhir/CodeSystem/{{csId}}
Authorization: {{auth}}
Content-Type: application/fhir+json

< ../../fsh-generated/resources/CodeSystem-{{csId}}.json

### Create ValueSet
PUT {{fhirServer}}/fhir/ValueSet/{{vsId}}
Authorization: {{auth}}
Content-Type: application/fhir+json

< ../../fsh-generated/resources/ValueSet-{{vsId}}.json

### Expand ValueSet (native endpoint)
GET {{aidboxServer}}/ValueSet/{{vsId}}/$expand
Authorization: {{auth}}

### Validate valid code
GET {{fhirServer}}/fhir/ValueSet/$validate-code?url={{vsUrl}}&system={{csUrl}}&code={{validCode}}
Authorization: {{auth}}

### Validate invalid code
GET {{fhirServer}}/fhir/ValueSet/$validate-code?url={{vsUrl}}&system={{csUrl}}&code=INVALID_XYZ
Authorization: {{auth}}

### Cleanup
DELETE {{fhirServer}}/fhir/ValueSet/{{vsId}}
Authorization: {{auth}}

### Cleanup CodeSystem
DELETE {{fhirServer}}/fhir/CodeSystem/{{csId}}
Authorization: {{auth}}
```

## 5. Testing Profiles

### Dependency Order

Profiles depend on other resources. Create them in order:

1. CodeSystems
2. ValueSets
3. Extension StructureDefinitions
4. Profile StructureDefinitions

### Upload Profile and Dependencies

```bash
# Upload all dependencies first
curl -s -u $AIDBOX_AUTH -X PUT "$AIDBOX_URL/fhir/CodeSystem/<cs-id>" \
  -H "Content-Type: application/fhir+json" -d @CodeSystem-<cs-id>.json

curl -s -u $AIDBOX_AUTH -X PUT "$AIDBOX_URL/fhir/ValueSet/<vs-id>" \
  -H "Content-Type: application/fhir+json" -d @ValueSet-<vs-id>.json

curl -s -u $AIDBOX_AUTH -X PUT "$AIDBOX_URL/fhir/StructureDefinition/<ext-id>" \
  -H "Content-Type: application/fhir+json" -d @StructureDefinition-<ext-id>.json

# Upload the profile itself
curl -s -u $AIDBOX_AUTH -X PUT "$AIDBOX_URL/fhir/StructureDefinition/<profile-id>" \
  -H "Content-Type: application/fhir+json" -d @StructureDefinition-<profile-id>.json
```

### Validate Examples

Use `$validate` to test without creating resources:

```bash
# Valid example — expect no errors in OperationOutcome
curl -s -u $AIDBOX_AUTH -X POST \
  "$AIDBOX_URL/fhir/<ResourceType>/\$validate?profile=<profile-url>" \
  -H "Content-Type: application/fhir+json" \
  -d @valid-example.json

# Invalid example — expect validation errors
curl -s -u $AIDBOX_AUTH -X POST \
  "$AIDBOX_URL/fhir/<ResourceType>/\$validate?profile=<profile-url>" \
  -H "Content-Type: application/fhir+json" \
  -d @invalid-example.json
```

**Do NOT** use PUT/POST to create test resources — use `$validate` to avoid polluting existing data.

### Testing Extensions

Extensions are not tested standalone. Embed them in a parent resource and validate the parent against a profile that references the extension.

### Testing Required Slices

For profiles with required slices, create an example that **omits** the required slice and verify that validation returns an error.

### httpyac Test File Format

Save as `test/Profile/<id>.http`:

```http
@fhirServer = http://localhost:8080
@auth = Basic basic:secret

### Create CodeSystem dependency
PUT {{fhirServer}}/fhir/CodeSystem/{{csId}}
Authorization: {{auth}}
Content-Type: application/fhir+json

< ../../fsh-generated/resources/CodeSystem-{{csId}}.json

### Create ValueSet dependency
PUT {{fhirServer}}/fhir/ValueSet/{{vsId}}
Authorization: {{auth}}
Content-Type: application/fhir+json

< ../../fsh-generated/resources/ValueSet-{{vsId}}.json

### Create Extension
PUT {{fhirServer}}/fhir/StructureDefinition/{{extId}}
Authorization: {{auth}}
Content-Type: application/fhir+json

< ../../fsh-generated/resources/StructureDefinition-{{extId}}.json

### Create Profile
PUT {{fhirServer}}/fhir/StructureDefinition/{{profileId}}
Authorization: {{auth}}
Content-Type: application/fhir+json

< ../../fsh-generated/resources/StructureDefinition-{{profileId}}.json

### Validate valid example (expect no errors)
POST {{fhirServer}}/fhir/{{resourceType}}/$validate?profile={{profileUrl}}
Authorization: {{auth}}
Content-Type: application/fhir+json

{
  "resourceType": "{{resourceType}}",
  ...
}

### Validate invalid example (expect errors)
POST {{fhirServer}}/fhir/{{resourceType}}/$validate?profile={{profileUrl}}
Authorization: {{auth}}
Content-Type: application/fhir+json

{
  "resourceType": "{{resourceType}}",
  ...
}

### Cleanup
DELETE {{fhirServer}}/fhir/StructureDefinition/{{profileId}}
Authorization: {{auth}}

DELETE {{fhirServer}}/fhir/StructureDefinition/{{extId}}
Authorization: {{auth}}

DELETE {{fhirServer}}/fhir/ValueSet/{{vsId}}
Authorization: {{auth}}

DELETE {{fhirServer}}/fhir/CodeSystem/{{csId}}
Authorization: {{auth}}
```

## 6. Publishing with IG Publisher

### Prerequisites

```bash
# Java (macOS — Homebrew keg-only, needs explicit PATH)
brew install openjdk
sudo ln -sfn $(brew --prefix openjdk)/libexec/openjdk.jdk \
  /Library/Java/JavaVirtualMachines/openjdk.jdk

# Jekyll
gem install jekyll

# IG Publisher JAR
mkdir -p input-cache
curl -L -o input-cache/publisher.jar \
  https://github.com/HL7/fhir-ig-publisher/releases/latest/download/publisher.jar
```

### PATH Setup

Homebrew Java and Jekyll gems may not be on the system PATH:

```bash
export JAVA_HOME=$(brew --prefix openjdk)/libexec/openjdk.jdk/Contents/Home
export PATH="$(ruby -e 'puts Gem.user_dir')/bin:$JAVA_HOME/bin:$PATH"
```

### Run IG Publisher

```bash
# Compile FSH first
sushi .

# Run IG Publisher (skip SUSHI since we just ran it)
java -jar input-cache/publisher.jar -ig . -no-sushi
```

Alternative layout (with separate ig-publisher directory):

```bash
# Copy generated resources to ig-publisher input
rm -rf ig-publisher/input/resources/*
cp target/*.json ig-publisher/input/resources/

# Clear previous output
rm -rf ig-publisher/output/*

# Run
cd ig-publisher && java -jar publisher.jar -ig ig.ini
```

### View Published IG

```bash
cd output && python3 -m http.server 8000 &
open http://localhost:8000/index.html
```

## 7. QA Review

### Check Results

```bash
# Quick summary
head -5 output/qa.txt

# Error count
grep "errors =" output/qa.html

# All errors (sorted by frequency)
grep "^ERROR:" output/qa.txt | sort | uniq -c | sort -rn

# All warnings
grep "^WARNING:" output/qa.txt | sort | uniq -c | sort -rn
```

### Categorize Issues

- **Blocking errors** — must fix before publishing
- **Strong warnings** — should fix (ShareableCodeSystem/ValueSet violations, missing required elements)
- **Informational** — can suppress if justified

### Common QA Issues and Fixes

| Issue | Fix |
|-------|-----|
| Missing `experimental` on CodeSystem/ValueSet | Add `* ^experimental = false` in FSH |
| ConceptMap target is CodeSystem not ValueSet | Change `targetCanonical` to a ValueSet URL |
| Resource ID / URL mismatch | Align FSH Instance name with `* url = ...` |
| ShareableCodeSystem/ValueSet violations | Add missing `experimental`, `name` elements |
| Deprecated extension references | Remove or replace with current equivalent |
| Unresolvable CodeSystem URL | Verify URL exists on tx.fhir.org or fix typo |

### Troubleshooting IG Publisher

| Error | Cause | Fix |
|-------|-------|-----|
| `Unable to locate a Java Runtime` | Java not on PATH | Set `JAVA_HOME` + `PATH` as shown above |
| `Cannot run program "jekyll"` | Jekyll not on PATH | Add gem bin dir to PATH |
| `Exec failed, error: 2` | Missing binary | Check both Java and Jekyll PATH |
| Stale `input-cache/publisher.jar` | Old IG Publisher version | Re-download from GitHub releases |

## 8. Common Pitfalls

### `$lookup` Not Implemented

Aidbox does **not** implement the FHIR `$lookup` operation on CodeSystems. Always use the native Concept API instead:

```bash
# WRONG — returns error
curl -s -u $AIDBOX_AUTH "$AIDBOX_URL/fhir/CodeSystem/\$lookup?system=<url>&code=<code>"

# CORRECT — use native Concept API
curl -s -u $AIDBOX_AUTH "$AIDBOX_URL/Concept?system=<url>&code=<code>"
```

### `$expand` — Use Native Endpoint

The FHIR endpoint for `$expand` may not work correctly. Use the Aidbox-native endpoint:

```bash
# Preferred — native endpoint
curl -s -u $AIDBOX_AUTH "$AIDBOX_URL/ValueSet/<id>/\$expand"

# FHIR endpoint — may fail or return incomplete results
curl -s -u $AIDBOX_AUTH "$AIDBOX_URL/fhir/ValueSet/<id>/\$expand"
```

### Two-Phase Terminology

Aidbox extracts CodeSystem concepts into a separate `Concept` table. After uploading a CodeSystem, codes are queryable via the Concept API even though they may not appear in `CodeSystem.concept` when you read the resource back. This is expected behavior.

### ConceptMap PUT in Transaction Bundles

ConceptMap resources may fail when included in transaction bundles via PUT. Upload them individually outside of bundles:

```bash
curl -s -u $AIDBOX_AUTH -X PUT "$AIDBOX_URL/fhir/ConceptMap/<id>" \
  -H "Content-Type: application/fhir+json" \
  -d @ConceptMap-<id>.json
```

### Large CodeSystems — PostgreSQL Parameter Limit

CodeSystems with thousands of codes can hit the PostgreSQL 65,535 parameter limit on insertion. Use the `$import` operation for large CodeSystems:

```bash
curl -s -u $AIDBOX_AUTH -X POST "$AIDBOX_URL/fhir/\$import" \
  -H "Content-Type: application/fhir+json" \
  -d @large-codesystem.ndjson
```

### Do Not Enable Strict Validation Globally

Use `$validate` with an explicit `profile` parameter for testing. Do not enable strict validation globally on the Aidbox instance — it may reject valid resources that don't conform to your custom profiles.

### Resource Validation on Create

Aidbox validates incoming resources against the profile specified in `meta.profile`. If you want to validate without creating:

```bash
POST $AIDBOX_URL/fhir/<ResourceType>/$validate
```
