---
name: fhir-validation
description: >
  FHIR resource validation with Aidbox and FHIR Schema. Use when interpreting validation errors,
  configuring validation in Aidbox, understanding FHIR Schema, debugging $validate responses,
  or comparing FHIR validators. Triggers on "validation error", "FHIR Schema", "$validate",
  "OperationOutcome", "why is my resource invalid", "validate resource", "fhir-schema",
  "validation engine", "invariant failed".
---

# FHIR Validation

Validate FHIR resources using Aidbox's FHIR Schema Validator, interpret OperationOutcome errors, and understand how FHIR Schema simplifies validation.

## When to use

- Interpreting `$validate` responses and OperationOutcome errors
- Configuring validation in Aidbox (engine selection, validation levels)
- Understanding what FHIR Schema is and how it differs from StructureDefinitions
- Debugging why a resource fails validation
- Comparing validation behavior across Aidbox, HL7 Java Validator, and Firely .NET SDK
- Migrating from Zen Schema or JSON Schema to FHIR Schema Validator

For IG-specific validation workflows (testing profiles, ValueSets, extensions), use the `aidbox-ig-development` skill instead.

## FHIR Schema

FHIR Schema is a simplified, language-agnostic representation of FHIR StructureDefinitions designed for validation and code generation. It is a FHIR community specification (Trial Use) created by Health Samurai.

### Why it exists

StructureDefinitions are complex and hard to implement correctly. Only a handful of complete validators exist because the validation algorithm is implicit and scattered across the FHIR spec. FHIR Schema makes the algorithm explicit:

- Properties map intuitively to data structure fields (inspired by JSON Schema)
- Clear operational semantics — each rule has an unambiguous meaning
- First-class array handling — distinguishes single elements from arrays
- Language-agnostic — implementable in JS, Python, Go, Rust, .NET, Java

### Schema structure

```json
{
  "url": "http://hl7.org/fhir/StructureDefinition/Patient",
  "type": "Patient",
  "name": "Patient",
  "base": "http://hl7.org/fhir/StructureDefinition/DomainResource",
  "derivation": "specialization",
  "required": ["name"],
  "elements": {
    "identifier": {
      "type": "Identifier",
      "array": true
    },
    "name": {
      "type": "HumanName",
      "array": true,
      "min": 1
    },
    "birthDate": {
      "type": "date"
    },
    "deceased": {
      "choices": ["deceasedBoolean", "deceasedDateTime"]
    }
  },
  "constraints": {
    "pat-1": {
      "expression": "name.where(use='official').exists()",
      "severity": "warning",
      "human": "Patient should have an official name"
    }
  }
}
```

### Key properties

| Property | Meaning |
|----------|---------|
| `elements` | Map of element name to definition (type, cardinality, binding, etc.) |
| `required` | Array of element names that must be present (min >= 1) |
| `excluded` | Array of element names forbidden in this profile (max = 0) |
| `constraints` | FHIRPath invariants with severity and human-readable description |
| `extensions` | Named extension definitions with URL, type, and cardinality |
| `derivation` | `specialization` (new type) or `constraint` (profile on existing type) |

### Resources

- Spec: https://fhir-schema.github.io/fhir-schema/
- GitHub: https://github.com/fhir-schema/fhir-schema
- Community: https://chat.fhir.org/#narrow/stream/391879-FHIR-Schema

## Validation in Aidbox

### Validator engines

Aidbox supports three validation engines. **FHIR Schema Validator is the recommended default** for new deployments.

| Feature | FHIR Schema | Zen Schema | JSON Schema |
|---------|:-----------:|:----------:|:-----------:|
| FHIRPath invariants | Yes | No | No |
| Forbidden elements (max 0) | Yes | No | No |
| Union type validation | Yes | No | No |
| All slicing types | Yes | Partial | No |
| Extension validation | Yes | No | No |
| Null value rejection | Yes | No (strips) | No (strips) |
| Reference targetProfile | Yes | Yes | Yes |
| Terminology bindings | Yes | Yes | Partial |

### Validation levels

Configure validation on create/update operations:

| Level | Behavior |
|-------|----------|
| `off` | No validation on write (only `$validate` works) |
| `core` | Syntax validation only (types, cardinality) |
| `full` | Full conformance validation (profiles, invariants, terminology) |

### $validate endpoint

Validate without persisting. Three scopes:

```http
# System-level — validate any resource
POST /fhir/$validate
Content-Type: application/fhir+json

{"resourceType": "Patient", "birthDate": "invalid"}

# Type-level — validate as specific resource type
POST /fhir/Patient/$validate
Content-Type: application/fhir+json

{"resourceType": "Patient", "name": [{"given": ["John"]}]}

# Against a specific profile
POST /fhir/Patient/$validate?profile=http://example.org/StructureDefinition/MyPatient
Content-Type: application/fhir+json

{
  "resourceType": "Patient",
  "meta": {"profile": ["http://example.org/StructureDefinition/MyPatient"]},
  "name": [{"given": ["John"], "family": "Doe"}]
}
```

## OperationOutcome reference

Every `$validate` response returns an OperationOutcome:

```json
{
  "resourceType": "OperationOutcome",
  "issue": [
    {
      "severity": "error",
      "code": "invalid",
      "expression": ["Patient.birthDate"],
      "diagnostics": "Expected type 'date', got 'string'"
    }
  ]
}
```

### Severity levels

| Severity | Meaning |
|----------|---------|
| `fatal` | Abort operation immediately |
| `error` | Validation failed, resource is non-conformant |
| `warning` | Non-blocking issue, operation can proceed |
| `information` | Informational only |

### Common issue codes and how to fix them

**`invalid` — Wrong type or format**
```json
{"severity": "error", "code": "invalid", "expression": ["Patient.birthDate"],
 "diagnostics": "Expected type 'date', got 'string'"}
```
Fix: Check the element type. Dates must be `YYYY`, `YYYY-MM`, or `YYYY-MM-DD`. DateTimes need time component.

**`required` — Missing required element**
```json
{"severity": "error", "code": "required", "expression": ["Patient.name"],
 "diagnostics": "Element 'name' is required (min cardinality: 1)"}
```
Fix: Add the missing element. Check the profile — it may require elements that the base spec does not.

**`structure` — Cardinality violation**
```json
{"severity": "error", "code": "structure", "expression": ["Patient.maritalStatus"],
 "diagnostics": "Expected single value, got array"}
```
Fix: Element has max cardinality 1 but was sent as an array. Use a single value instead.

**`forbidden` — Element prohibited by profile**
```json
{"severity": "error", "code": "forbidden", "expression": ["Patient.contact[0].name"],
 "diagnostics": "Element is forbidden in this profile (max cardinality: 0)"}
```
Fix: Remove the element. The active profile sets `max: 0` for this element.

**`code-invalid` — Terminology binding violation**
```json
{"severity": "error", "code": "code-invalid", "expression": ["Observation.status"],
 "diagnostics": "Code 'unknown' not in ValueSet: http://hl7.org/fhir/ValueSet/observation-status"}
```
Fix: Use a code from the bound ValueSet. Check binding strength — `required` bindings must match exactly, `extensible` allows codes outside the set with a text fallback.

**`invariant` — FHIRPath constraint failed**
```json
{"severity": "error", "code": "invariant", "expression": ["Observation"],
 "diagnostics": "Invariant obs-7 failed: If Observation.effective[x] is dateTime, the value SHALL be precise to at least the day"}
```
Fix: Read the invariant description. These are business rules defined by the spec or profile. The `diagnostics` field explains what went wrong.

**`invalid-target-profile` — Reference target doesn't conform**
```json
{"severity": "error", "code": "invalid-target-profile",
 "diagnostics": "Referenced resource Observation/xyz doesn't conform to any of target profiles: http://example.org/StructureDefinition/LabObservation"}
```
Fix: The referenced resource must conform to the profile(s) listed in `targetProfile`. Validate the referenced resource separately to find what's wrong with it.

### Null value errors

The FHIR Schema Validator rejects `null` values (FHIR-compliant). Zen and JSON Schema validators silently strip nulls.

```json
// BAD — will fail
{"resourceType": "Patient", "birthDate": null}

// GOOD — omit the element entirely
{"resourceType": "Patient"}

// GOOD — use data-absent-reason extension if element is required but unknown
{"resourceType": "Patient", "_birthDate": {
  "extension": [{"url": "http://hl7.org/fhir/StructureDefinition/data-absent-reason",
                  "valueCode": "unknown"}]
}}
```

## Cross-validator comparison

When validation results differ between tools, check these known divergences:

| Behavior | Aidbox (FHIR Schema) | HL7 Java Validator | Firely .NET SDK |
|----------|:-------------------:|:-----------------:|:--------------:|
| Null values | Error | Error | Strips silently |
| Unknown extensions | Passes (open) | Warning | Warning |
| Slicing: unmatched elements in closed slice | Error | Error | May differ on edge cases |
| Invariant evaluation engine | FHIRPath | FHIRPath | FluentPath/.NET |
| Terminology: unknown ValueSet | Warning | Error | Configurable |
| Reference target validation | Resolves and validates content | Resolves if available | Configurable |

### Testing across validators

For maximum confidence, test critical profiles against multiple validators:

1. **Aidbox** — `POST /fhir/<Type>/$validate?profile=<url>` (your runtime environment)
2. **HL7 Java Validator** — `java -jar validator_cli.jar resource.json -ig <ig-package> -profile <url>`
3. **Simplifier.net** — Upload to https://simplifier.net/validate for Firely validation

If results diverge, the HL7 Java Validator is the reference implementation. File bugs against other validators when they disagree with it.

## Debugging validation failures

### Step-by-step approach

1. **Read the OperationOutcome carefully** — `expression` tells you which element, `diagnostics` tells you why
2. **Check the profile** — `GET /fhir/StructureDefinition?url=<profile-url>` to see what constraints apply
3. **Validate incrementally** — Start with a minimal valid resource, add elements one by one
4. **Check terminology** — For `code-invalid` errors, verify the ValueSet: `GET /fhir/ValueSet/$expand?url=<vs-url>`
5. **Check references** — For `invalid-target-profile`, validate the referenced resource separately
6. **Compare engines** — If unsure whether it's a validator bug, test with the HL7 Java Validator

### Common pitfalls

- **Profile not loaded**: Aidbox validates against `meta.profile` only if the StructureDefinition is loaded. POST the SD first.
- **Extension URL mismatch**: Extension URLs are case-sensitive and must match exactly.
- **Binding strength confusion**: `required` = must match, `extensible` = should match (allows custom codes with text), `preferred`/`example` = informational only.
- **Slicing discriminator mismatch**: If a slice uses `type` discriminator, the resource element must have the exact type specified in the slice definition.
- **Date vs DateTime**: `2024-01-15` is a `date`, `2024-01-15T10:30:00Z` is a `dateTime`. They are not interchangeable.

## Aidbox documentation

For setup instructions, migration guides, and advanced configuration, use the `hs-search` skill or fetch directly:

```bash
# FHIR Schema Validator setup
curl -s 'https://www.health-samurai.io/docs/aidbox/modules/profiling-and-validation/fhir-schema-validator'

# Validator comparison
curl -s 'https://www.health-samurai.io/docs/aidbox/modules/profiling-and-validation/fhir-schema-validator/setup-aidbox-with-fhir-schema-validation-engine'

# Migration from Zen Schema
curl -s 'https://www.health-samurai.io/docs/aidbox/modules/profiling-and-validation'
```
