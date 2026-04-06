---
name: aidbox
description: >
  Aidbox FHIR platform by Health Samurai. Use when user works with Aidbox — FHIR REST API,
  CRUD operations, search, transactions, bundles, access policies, subscriptions, custom
  resources, SQL on FHIR, bulk operations, terminology, profiles, Aidbox configuration,
  docker setup, environment variables, Aidbox SDK,
  AccessPolicy, SearchParameter, AidboxSubscription, AidboxTopicDestination, Operation,
  or any Aidbox-specific features. Also triggers on mentions of
  "aidbox", "aidboxone", "devbox", "multibox", "aidbox forms", "aidbox MPI".
---

# Aidbox FHIR Platform

Aidbox is a FHIR-native platform built on PostgreSQL. It provides FHIR API with extensions for real-world production use.

## Documentation

Aidbox docs live at `https://www.health-samurai.io/docs/aidbox`.

When you need to look up Aidbox documentation, use the `hs-search` skill — it can search and fetch full pages from health-samurai.io docs. Invoke it with `/hs-search` or let it trigger automatically when searching for Aidbox docs.

## Architecture

- **Storage**: PostgreSQL with JSONB, each FHIR resource type maps to a table
- **API layers**: FHIR REST, SQL, GraphQL, Subscriptions
- **Auth**: OAuth 2.0, SMART on FHIR, RBAC/ABAC via AccessPolicy
- **Validation**: FHIR Schema (simplified StructureDefinitions), FHIRPath invariants
- **Config**: Environment variables + Init Bundle

## Setting Up a New Aidbox Instance

To quickly set up a new Aidbox instance with Docker Compose:

```bash
# Download the docker-compose.yml
curl -JO https://aidbox.app/runme

# Start Aidbox
docker compose up -d
```

This downloads a pre-configured `docker-compose.yml` with recommended environment variables. Always use a fresh download — don't write docker-compose.yml manually. After starting, read the downloaded file to find the port (`AIDBOX_PORT`) and root client secret (`BOX_ROOT_CLIENT_SECRET`).

Open the Aidbox UI in the browser (check the port in `docker-compose.yml`, typically `http://localhost:8080`). On first launch, click "Continue with Aidbox account" to create a free account at https://aidbox.app/ and activate the instance.

For the full getting started guide, fetch:

```bash
curl -s 'https://www.health-samurai.io/docs/aidbox/getting-started/run-aidbox-locally.md'
```

## Init Bundle

Init Bundle is the primary way to configure Aidbox. It executes a FHIR Bundle at startup, before the HTTP server starts, to load configuration resources (AccessPolicy, SearchParameter, SubscriptionTopic, custom StructureDefinitions, seed data, etc.).

### Setup

Set `BOX_INIT_BUNDLE` in `docker-compose.yml` to point to your bundle file:

```yaml
environment:
  BOX_INIT_BUNDLE: file:///app/init-bundle.json
```

Supported URL schemes: `file:///path/to/bundle.json`, `https://storage.googleapis.com/...`

### Bundle format

Only JSON format is supported. Use `transaction` (all-or-nothing — startup fails if any entry fails) or `batch` (partial failures produce warnings but don't block startup):

```json
{
  "resourceType": "Bundle",
  "type": "transaction",
  "entry": [
    {
      "resource": {
        "resourceType": "AccessPolicy",
        "id": "as-my-app-crud-patients",
        "engine": "matcho",
        "link": [{"reference": "Client/my-app"}],
        "matcho": {
          "params": {"resource/type": "Patient"},
          "request-method": {"$enum": ["get", "post", "put", "patch"]}
        }
      },
      "request": { "method": "PUT", "url": "AccessPolicy/as-my-app-crud-patients" }
    }
  ]
}
```

### Best practices

- **Test before using as init bundle**: POST the bundle to `/fhir` manually first. Post it multiple times to confirm it is idempotent.
- **Use conditional creates for seed data**: use `ifNoneExist` in requests to avoid duplicate key errors on restart.
- **Use PUT with explicit ids** for configuration resources (AccessPolicy, SearchParameter) so they are updated on restart.
- Environment variables can be injected into the bundle using `envsubst`.

### Loading FHIR Implementation Guides

Init Bundle can load FHIR IGs automatically at startup. Search the docs for details:

```bash
curl -s 'https://www.health-samurai.io/api/llm/search?q=load+FHIR+IG+init+bundle&limit=5'
```

For full documentation:

```bash
curl -s 'https://www.health-samurai.io/docs/aidbox/configuration/init-bundle.md'
```

## FHIR REST API

### Base URL

**Always use the `/fhir/` prefix** for all Aidbox API interactions (e.g., `/fhir/Patient`, `/fhir/Observation`). Never use URLs without the `/fhir/` prefix — the non-prefixed format (`/Patient`) is deprecated.

### Authentication

For applications, create a dedicated `Client` resource with appropriate AccessPolicies (see Access Policies section). Load it via Init Bundle:

```json
{
  "resourceType": "Client",
  "id": "my-app",
  "secret": "<my-app-secret>",
  "grant_types": ["basic"]
}
```

Then authenticate with Basic Auth:

```bash
curl -s -u "my-app:my-app-secret" "http://localhost:<port>/fhir/Patient"
```

For quick manual testing only, use the root client (`root` / password from `BOX_ROOT_CLIENT_SECRET` in `docker-compose.yml`). The root client bypasses all access policies — never use it in application code.

```bash
# Root client — for debugging/testing only
curl -s -u "root:<BOX_ROOT_CLIENT_SECRET>" "http://localhost:<port>/fhir/Patient"
```

### CRUD

```bash
# Read a specific resource
curl -s -u "<client>:<secret>" "http://localhost:<port>/fhir/Patient/<id>" | python3 -m json.tool

# Search resources
curl -s -u "<client>:<secret>" "http://localhost:<port>/fhir/Patient?name=John&_count=10" | python3 -m json.tool

# Create (POST)
curl -s -u "<client>:<secret>" -X POST "http://localhost:<port>/fhir/Patient" \
  -H "Content-Type: application/fhir+json" \
  -d '{"resourceType":"Patient","name":[{"given":["Test"],"family":"User"}]}' | python3 -m json.tool

# Update (PUT) — requires id in both URL and body
curl -s -u "<client>:<secret>" -X PUT "http://localhost:<port>/fhir/Patient/<id>" \
  -H "Content-Type: application/fhir+json" \
  -d '{"resourceType":"Patient","id":"<id>","name":[{"given":["Updated"],"family":"User"}]}' | python3 -m json.tool

# Partial update (PATCH)
curl -s -u "<client>:<secret>" -X PATCH "http://localhost:<port>/fhir/Patient/<id>" \
  -H "Content-Type: application/merge-patch+json" \
  -d '{"birthDate":"1990-01-01"}' | python3 -m json.tool

# Delete
curl -s -u "<client>:<secret>" -X DELETE "http://localhost:<port>/fhir/Patient/<id>"

# History
curl -s -u "<client>:<secret>" "http://localhost:<port>/fhir/Patient/<id>/_history" | python3 -m json.tool
```

### Search

```http
GET /fhir/Patient?name=John&birthdate=gt1990-01-01
GET /fhir/Patient?_include=Patient:organization
GET /fhir/Patient?_revinclude=Observation:subject
GET /fhir/Patient?_has:Observation:subject:code=http://loinc.org|1234
GET /fhir/Patient?_sort=-birthdate&_count=10&_page=2
```

Search modifiers: `:exact`, `:contains`, `:missing`, `:not`, `:text`, `:of-type`
Prefixes for date/number: `eq`, `ne`, `gt`, `lt`, `ge`, `le`, `sa`, `eb`, `ap`

### Bundles (Transaction/Batch)

```bash
curl -s -u "<client>:<secret>" -X POST "http://localhost:<port>/fhir" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Bundle",
    "type": "transaction",
    "entry": [
      {
        "fullUrl": "urn:uuid:patient-1",
        "resource": {"resourceType": "Patient", "name": [{"family": "Smith"}]},
        "request": {"method": "POST", "url": "Patient"}
      },
      {
        "resource": {"resourceType": "Observation", "subject": {"reference": "urn:uuid:patient-1"}},
        "request": {"method": "POST", "url": "Observation"}
      }
    ]
  }' | python3 -m json.tool
```

Transaction = all-or-nothing. Batch = independent operations, partial success OK.

### Conditional Operations

```http
PUT    /fhir/Patient?identifier=http://mrn|12345    # Conditional create/update
DELETE /fhir/Patient?identifier=http://mrn|12345    # Conditional delete
```

### $validate

```http
POST /fhir/Patient/$validate
Content-Type: application/fhir+json

{"resourceType": "Patient", "birthDate": "invalid"}
```

## Aidbox-Specific Features

### Custom Resources

Define custom resource types using StructureDefinition (the recommended approach). The `id`, `name`, and `type` must match; set `derivation: specialization` to create a new resource type with its own database table.

For a full tutorial with examples, use the `hs-search` skill or fetch:

```bash
curl -s 'https://www.health-samurai.io/docs/aidbox/tutorials/artifact-registry-tutorials/custom-resources/custom-resources-using-structuredefinition.md'
```

### Access Policies

Use the `matcho` engine (recommended). Link policies to `Client`, `User`, or `Operation` — unlinked policies are global and evaluate on every request, hurting performance.

#### Client CRUD on specific resource types

```yaml
id: as-my-app-crud-patients-and-practitioners
resourceType: AccessPolicy
engine: matcho
link:
  - reference: Client/my-app
matcho:
  params:
    resource/type:
      $enum:
        - Patient
        - Practitioner
  request-method:
    $enum:
      - get
      - post
      - patch
      - put
```

#### Client allowed to use FHIR transactions

```yaml
id: as-my-app-allowed-to-use-fhir-transactions
resourceType: AccessPolicy
engine: matcho
link:
  - reference: Client/my-app
matcho:
  operation:
    id: FhirTransaction
```

Note: this only allows access to the `/fhir` transaction endpoint. Individual resource operations within the bundle need their own policies.

#### Patient viewing own data

```yaml
id: as-patient-get-own-data
resourceType: AccessPolicy
engine: matcho
link:
  - reference: Operation/FhirRead
matcho:
  params:
    resource/id: .user.fhirUser.id
    resource/type: Patient
```

#### Best practices

- **Name with `as-` prefix**: describe the audience and action (e.g., `as-practitioner-read-observations`)
- **Always link** to `Client`, `User`, or `Operation` — avoid global policies
- **Test `.` paths for `present?`**: if both sides of a `.user.data.field` comparison are missing, matcho may evaluate to true. Add explicit `present?` checks:
  ```yaml
  matcho:
    body:
      subject: .user.data.patient
    user:
      data:
        patient: present?
  ```
- **Disable unsafe search params** on public endpoints:
  ```yaml
  matcho:
    params:
      _include: nil?
      _revinclude: nil?
      _with: nil?
      _assoc: nil?
  ```
- **Prefer small, separate policies** over `complex` with `or` — easier to maintain and Aidbox logs which policy granted access
- **Avoid regex** when plain strings or `$one-of` work

For more examples and best practices:

```bash
curl -s 'https://www.health-samurai.io/docs/aidbox/tutorials/security-access-control-tutorials/accesspolicy-examples.md'
curl -s 'https://www.health-samurai.io/docs/aidbox/tutorials/security-access-control-tutorials/accesspolicy-best-practices.md'
```

To inspect current policies:

```bash
curl -s -u "<client>:<secret>" "http://localhost:<port>/fhir/AccessPolicy?_count=50" | python3 -m json.tool
```

### SQL API

```http
POST /$sql
Content-Type: text/yaml

- select * from patient where resource->>'birthDate' > '1990-01-01' limit 10
```

Or via `/$psql` for interactive queries. Tables follow naming: resource type in lowercase (e.g., `patient`, `observation`). Resource stored in `resource` JSONB column.

### Subscriptions (Topic-Based)

```json
{
  "resourceType": "AidboxTopicDestination",
  "topic": "http://example.com/patient-changes",
  "kind": "webhook",
  "url": "https://my-service.com/webhook",
  "filter": [{"resourceType": "Patient"}]
}
```

### Bulk API

```http
GET /fhir/$export                    # System-level export
GET /fhir/Group/<id>/$export         # Group export
POST /fhir/$import                   # Bulk import (ndjson)
```

### Terminology

```http
GET  /fhir/ValueSet/$expand?url=<vs-url>&filter=<text>
POST /fhir/CodeSystem/$lookup
POST /fhir/ConceptMap/$translate
```

## TypeScript SDK: @health-samurai/aidbox-client

Install (ESM-only package):

```bash
npm install @health-samurai/aidbox-client@^0.0.0-alpha.5
```

### Initialization

```typescript
import { AidboxClient, BasicAuthProvider } from "@health-samurai/aidbox-client";

// Use a dedicated Client resource (see Authentication section)
const baseUrl = "http://localhost:8888";
const client = new AidboxClient(baseUrl, new BasicAuthProvider(baseUrl, "my-app", "my-app-secret"));
```

Auth providers:
- `BasicAuthProvider(baseUrl, username, password)` — HTTP Basic Auth (server-side)
- `BrowserAuthProvider(baseUrl)` — cookie-based sessions (browser)
- `SmartBackendServicesAuthProvider(...)` — OAuth 2.0 SMART Backend Services

### Result Type

All methods return `Result<ResourceResponse<T>, ResourceResponse<OperationOutcome>>`:

```typescript
const result = await client.read<Patient>({ type: "Patient", id: "pt-1" });
if (result.isOk()) {
  const patient = result.value.resource;
} else {
  const error = result.value.resource; // OperationOutcome
}
```

### CRUD

```typescript
// Read
const result = await client.read<Patient>({ type: "Patient", id: "pt-1" });

// Create
const result = await client.create<Patient>({
  type: "Patient",
  resource: { resourceType: "Patient", gender: "female" },
});

// Update (PUT)
const result = await client.update<Patient>({
  type: "Patient",
  id: "pt-1",
  resource: { resourceType: "Patient", name: [{ family: "Smith" }] },
});

// Patch (JSON Patch)
const result = await client.patch<Patient>({
  type: "Patient",
  id: "pt-1",
  patch: [{ op: "replace", path: "/name/0/family", value: "NewName" }],
});

// Delete
const result = await client.delete<Patient>({ type: "Patient", id: "pt-1" });

```

Conditional variants also available: `conditionalCreate`, `conditionalUpdate`, `conditionalPatch`, `conditionalDelete` — pass `searchParameters: [["key", "value"]]` instead of `id`.

### Search

Search parameters are `[string, string][]` tuples (allows duplicate keys like multiple `_include`):

```typescript
// Type-level search
const result = await client.searchType({
  type: "Patient",
  query: [["family", "Smith"], ["_count", "10"]],
});
if (result.isOk()) {
  const bundle = result.value.resource; // Bundle with entries
}

// System-level search
const result = await client.searchSystem({
  query: [["_type", "Patient"], ["family", "Test"]],
});

// Compartment search
const result = await client.searchCompartment({
  compartment: "Patient",
  compartmentId: "pt-1",
  type: "Observation",
  query: [["status", "final"]],
});
```

### Transaction / Batch

```typescript
const result = await client.transaction({
  format: "application/json",
  bundle: {
    resourceType: "Bundle",
    type: "transaction",
    entry: [
      {
        request: { method: "POST", url: "Patient" },
        resource: { resourceType: "Patient", name: [{ family: "Doe" }] },
      },
      {
        request: { method: "DELETE", url: "Patient/some-id" },
      },
    ],
  },
});

// Batch (partial success OK)
const result = await client.batch({
  format: "application/json",
  bundle: { resourceType: "Bundle", type: "batch", entry: [...] },
});
```

### Operations

```typescript
// $validate
const result = await client.validate<Patient>({
  type: "Patient",
  resource: patientResource,
});

// Custom operation
const result = await client.operation<InputType, OutputType>({
  type: "Patient",
  id: "pt-1",
  operation: "$everything",
  resource: { /* parameters */ },
});
```

### Raw SQL and Low-Level Requests

Use `rawRequest` for Aidbox-specific endpoints (no built-in `$sql` method):

```typescript
// SQL query
const result = await client.rawRequest({
  method: "POST",
  url: "/$sql",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(["SELECT * FROM patient WHERE id = ?", "pt-1"]),
});
const rows = await result.response.json();

// Any Aidbox endpoint — rawRequest throws on errors, request returns Result<T>
const result = await client.request<MyType>({
  method: "POST",
  url: "/custom-endpoint",
  body: JSON.stringify(data),
});
```

### FHIR Types

For full FHIR type coverage, use the `atomic-generate-types` skill to generate TypeScript types from FHIR packages.

## Production Pitfalls

Common issues encountered in production Aidbox deployments. These are easy to hit and hard to diagnose.

### Content-Type 422 trap

Aidbox has two API layers with different Content-Type requirements:

| Endpoint type | URL pattern | Required Content-Type |
|---|---|---|
| **FHIR** | `/fhir/Patient`, `/fhir/Encounter`, etc. | `application/fhir+json` |
| **Native** | `/$sql`, `/ViewDefinition`, `/$import`, etc. | `application/json` |

Sending the wrong Content-Type returns a 422 Unprocessable Entity that looks like a validation error but is actually a content negotiation failure. If you get an unexpected 422, check the Content-Type header first.

```bash
# Correct — FHIR endpoint
curl -X POST "http://localhost:<port>/fhir/Patient" \
  -H "Content-Type: application/fhir+json" \
  -d '{"resourceType":"Patient"}'

# Correct — native endpoint
curl -X POST "http://localhost:<port>/$sql" \
  -H "Content-Type: application/json" \
  -d '["SELECT 1"]'
```

### Pagination: _offset returns empty silently

The `_offset` search parameter returns empty results without any error or warning. For pagination, follow the Bundle `next` link instead:

```bash
# WRONG — silently returns empty
GET /fhir/Patient?_count=10&_offset=10

# RIGHT — follow next link from Bundle response
GET /fhir/Patient?_count=10
# Then follow response.link[rel="next"].url
```

Also be aware that `_count` defaults may return fewer results than exist. Always use `_summary=count` to get the true total:

```bash
# Get true total count
GET /fhir/Patient?_summary=count
# Response: {"total": 4523, ...}
```

### $materialize DROP+REBUILD

When using `$materialize` with `type=table`, Aidbox drops the entire table and rebuilds it from scratch. On large tables (millions of rows), this means minutes of downtime where the table does not exist.

`$materialize` is safe for initial bootstrap on empty databases. For production use with large tables, implement incremental sync (e.g., using the Changes API or AidboxTriggers) instead of repeated `$materialize` calls.

## Debugging

### "Forbidden" errors
1. Check if the resource type is allowed in the relevant AccessPolicy
2. Use the root/admin client to bypass access policies for debugging
3. Inspect policies: `curl -s -u "<root>:<secret>" "http://localhost:<port>/fhir/AccessPolicy?_count=50"`
4. Test access: `POST /$access-policy-check`

### Check Aidbox health

```bash
curl -s "http://localhost:<port>/health" | python3 -m json.tool
```

### Inspect a resource

```bash
curl -s -u "<client>:<secret>" "http://localhost:<port>/fhir/<ResourceType>/<id>" | python3 -m json.tool
```

### Upload init bundle to running instance

To apply init bundle changes without restarting:

```bash
curl -s -u "<root>:<secret>" -X POST "http://localhost:<port>/fhir" \
  -H "Content-Type: application/fhir+json" \
  -d @init-bundle.json | python3 -m json.tool
```
