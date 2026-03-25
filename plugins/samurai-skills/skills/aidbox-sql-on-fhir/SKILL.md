---
name: aidbox-sql-on-fhir
description: >
  SQL on FHIR with Aidbox — ViewDefinitions, $materialize, sof schema.
  Use when user works with ViewDefinition resources, $materialize, sof schema,
  flattening FHIR data into SQL tables, dashboard queries, or analytics over FHIR data
  in Aidbox. Also triggers on "SQL on FHIR", "ViewDefinition", "sof schema",
  "materialize", "FHIR analytics", "FHIR dashboard".
---

# Aidbox Dashboard — SQL on FHIR

Build dashboards and analytics on Aidbox by flattening FHIR resources into SQL tables using **SQL on FHIR ViewDefinitions**.

## Overview

The approach has three steps:

1. **Define a ViewDefinition** — a FHIR resource that describes how to flatten a FHIR resource into tabular columns
2. **Upload and materialize** — upload the ViewDefinition to Aidbox and call `$materialize` to create SQL tables in the `sof` schema
3. **Query with SQL** — query `sof.<view_name>` tables directly via PostgreSQL for dashboard data

## Creating a ViewDefinition

A ViewDefinition is a FHIR resource. It can be uploaded via the FHIR API:

```http
PUT /ViewDefinition/patient-demographics

{
  "resourceType": "ViewDefinition",
  "id": "patient-demographics",
  "name": "patient_demographics",
  "status": "active",
  "resource": "Patient",
  "select": [
    {
      "column": [
        { "path": "getResourceKey()", "name": "id" },
        { "path": "gender", "name": "gender" },
        { "path": "birthDate", "name": "birth_date" }
      ]
    },
    {
      "forEachOrNull": "name.where(use = 'official').first()",
      "column": [
        { "path": "given.join(' ')", "name": "given_name" },
        { "path": "family", "name": "family_name" }
      ]
    }
  ]
}
```

If the project uses an init bundle pattern (JSON files assembled into a transaction bundle), wrap ViewDefinitions as bundle entries:

```json
{
  "request": { "method": "PUT", "url": "/ViewDefinition/patient-demographics" },
  "resource": { ... }
}
```

## Materializing ViewDefinitions

After uploading a ViewDefinition, call `$materialize` to create/refresh the corresponding SQL table in the `sof` schema:

```http
POST /ViewDefinition/<id>/$materialize
```

This creates a table `sof.<name>` where `<name>` is the ViewDefinition's `name` field.

ViewDefinitions loaded via `BOX_INIT_BUNDLE` on Aidbox startup still need a `$materialize` call to create the SQL tables.

## Running ViewDefinitions On-the-Fly ($run)

The `$run` operation executes a ViewDefinition without materializing a table. Useful for testing ViewDefinitions and ad-hoc queries. Requires Aidbox 2507+.

```http
POST /fhir/ViewDefinition/<id>/$run
Content-Type: application/json
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `viewReference` | Reference to a stored ViewDefinition |
| `viewResource` | Inline ViewDefinition (instead of referencing a stored one) |
| `resource` | Individual FHIR resources to process (repeatable). When omitted, processes stored resources |
| `group` | Restrict to resources in the specified group |
| `patient` | Filter to resources in the patient compartment |
| `_since` | Process only resources modified after this timestamp |
| `_format` | Output format: `json`, `ndjson`, or `csv` |
| `_limit` | Max number of returned rows |

### Examples

Run a stored ViewDefinition against stored resources:

```http
POST /fhir/ViewDefinition/body-weight/$run
Content-Type: application/json

{
  "resourceType": "Parameters",
  "parameter": [
    { "name": "_format", "valueString": "json" },
    { "name": "_limit", "valueInteger": 10 }
  ]
}
```

Run an inline ViewDefinition against inline resources (useful for testing):

```http
POST /fhir/ViewDefinition/$run
Content-Type: application/json

{
  "resourceType": "Parameters",
  "parameter": [
    {
      "name": "viewResource",
      "resource": {
        "resourceType": "ViewDefinition",
        "name": "test_view",
        "resource": "Patient",
        "status": "active",
        "select": [{ "column": [{ "path": "getResourceKey()", "name": "id" }] }]
      }
    },
    {
      "name": "resource",
      "resource": {
        "resourceType": "Patient",
        "id": "pt-1",
        "gender": "male"
      }
    },
    { "name": "_format", "valueString": "json" }
  ]
}
```

## Querying Materialized Views

Once materialized, query the `sof` schema with standard SQL:

```sql
SELECT effective_date, weight_kg, unit
FROM sof.body_weight
WHERE patient_id = 'pt-1'
ORDER BY effective_date;
```

### Database Connection

PostgreSQL credentials are typically in `docker-compose.yaml` under `services.postgres.environment`:

| Parameter | Source |
|-----------|--------|
| Host | `localhost` |
| Port | `5432` |
| Database | `POSTGRES_DB` |
| User | `POSTGRES_USER` |
| Password | `POSTGRES_PASSWORD` |

Connection string: `postgresql://<user>:<password>@localhost:5432/<database>`

## ViewDefinition Reference

### Structure

| Field | Required | Description |
|-------|----------|-------------|
| `resourceType` | yes | `"ViewDefinition"` |
| `name` | yes | SQL table name (used as `sof.<name>`). Must match `^[A-Za-z][A-Za-z0-9_]*$` |
| `resource` | yes | Target FHIR resource type (e.g., `"Patient"`, `"Observation"`) |
| `status` | yes | `"active"`, `"draft"`, `"retired"`, or `"unknown"` |
| `select` | yes | Array of select blocks defining output columns |
| `where` | no | Array of FHIRPath filter expressions |
| `constant` | no | Named constants referenced as `%name` in FHIRPath |

### Select Block

| Field | Description |
|-------|-------------|
| `column` | Array of `{ path, name }` — FHIRPath expression and output column name |
| `forEach` | FHIRPath expression to iterate (creates multiple rows per resource) |
| `forEachOrNull` | Like `forEach` but emits a row with nulls when the collection is empty |
| `unionAll` | Combine multiple select structures |
| `select` | Nested select (cross-join with parent) |

### Common FHIRPath Expressions

| Expression | Description |
|------------|-------------|
| `getResourceKey()` | Resource ID |
| `subject.getReferenceKey(Patient)` | Referenced Patient ID (for joins) |
| `gender` | Direct field access |
| `birthDate` | Direct field access |
| `name.where(use = 'official').first()` | Filter and pick first |
| `given.join(' ')` | Join array into string |
| `effective.ofType(dateTime)` | Polymorphic field access |
| `value.ofType(Quantity).value` | Quantity value |
| `value.ofType(Quantity).unit` | Quantity unit |
| `code.coding` | Iterate over codings |
| `code.coding.where(system='http://loinc.org').first()` | Pick specific coding |
| `code.coding.where(system = 'http://loinc.org' and code = '29463-7').exists()` | Filter by coding system + code |

## ViewDefinition Examples

### Filtered Observation (Body Weight)

```json
{
  "resourceType": "ViewDefinition",
  "id": "body-weight",
  "name": "body_weight",
  "status": "active",
  "resource": "Observation",
  "where": [
    {
      "path": "code.coding.where(system = 'http://loinc.org' and code = '29463-7').exists()"
    }
  ],
  "select": [
    {
      "column": [
        { "path": "getResourceKey()", "name": "id" },
        { "path": "subject.getReferenceKey(Patient)", "name": "patient_id" },
        { "path": "effective.ofType(dateTime)", "name": "effective_date" },
        { "path": "value.ofType(Quantity).value", "name": "weight_kg" },
        { "path": "value.ofType(Quantity).unit", "name": "unit" },
        { "path": "status", "name": "status" }
      ]
    }
  ]
}
```

Creates `sof.body_weight` with columns: `id`, `patient_id`, `effective_date`, `weight_kg`, `unit`, `status`.

### Generic Observation with Coding

```json
{
  "resourceType": "ViewDefinition",
  "id": "observation-values",
  "name": "observation_values",
  "status": "active",
  "resource": "Observation",
  "select": [
    {
      "column": [
        { "path": "getResourceKey()", "name": "id" },
        { "path": "subject.getReferenceKey(Patient)", "name": "patient_id" },
        { "path": "status", "name": "status" },
        { "path": "effective.ofType(dateTime)", "name": "effective_date" },
        { "path": "value.ofType(Quantity).value", "name": "value" },
        { "path": "value.ofType(Quantity).unit", "name": "unit" }
      ]
    },
    {
      "forEachOrNull": "code.coding.first()",
      "column": [
        { "path": "system", "name": "code_system" },
        { "path": "code", "name": "code" },
        { "path": "display", "name": "code_display" }
      ]
    }
  ]
}
```

## Querying FHIR Resources via API

```sh
# Read a resource
curl -s -u "<client>:<secret>" "http://localhost:8080/fhir/Patient/<id>"

# Search resources
curl -s -u "<client>:<secret>" "http://localhost:8080/fhir/Patient?name=John&_count=10"
```

Always use the `/fhir/` prefix. Without it, you get the Aidbox-native format instead of FHIR.

## Auth Clients

Aidbox projects typically have two clients:

| Client | Use for |
|--------|---------|
| **Application client** | Normal CRUD, search, transactions |
| **Root client** | Admin operations — uploading bundles, materializing ViewDefinitions |

Credentials are found in `docker-compose.yaml` (root client via `BOX_ROOT_CLIENT_SECRET`) and in FHIR definition files (application client).

## Debugging

```sh
# Check Aidbox health
curl -s http://localhost:8080/health

# List ViewDefinitions
curl -s -u "<client>:<secret>" "http://localhost:8080/ViewDefinition?_count=50"

# Inspect a resource
curl -s -u "<client>:<secret>" "http://localhost:8080/fhir/<ResourceType>/<id>"

# Test a materialized view exists
docker compose exec postgres psql -U <user> -d <database> -c "SELECT * FROM sof.<view_name> LIMIT 5;"
```
