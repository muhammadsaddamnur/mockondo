# Mockondo

**A no-code mock server for frontend developers.**

Mockondo lets you spin up a local HTTP server, define endpoints, and return realistic dynamic responses — all without writing a single line of backend code. Built with Flutter, it runs as a native desktop app on macOS, Windows, and Linux.

---

## Features

| Feature | Description |
|---|---|
| **Multi-project management** | Create and switch between multiple mock API projects, each with its own host and port. |
| **HTTP mock server** | Run a Shelf-based local server on any port; start/stop with one click. |
| **Response interpolation** | Use `${...}` placeholders in response bodies and headers for dynamic, realistic data. |
| **Conditional response rules** | Return different responses based on query params, headers, body fields, or route params. |
| **Pagination simulation** | Generate paginated data from a per-item template with configurable `limit` and `page` params. |
| **Artificial response delay** | Simulate network latency per-endpoint (milliseconds). |
| **Custom data store** | Define reusable lists of values and reference them via `${customdata.*}` in responses. |
| **Built-in HTTP client** | Send requests to any URL directly from the app to test your mock endpoints. |
| **Request terminal** | Live log of all incoming requests with method, path, status code, and response time. |
| **Interpolation autocomplete** | All text fields support `${` autocomplete suggestions for the full interpolation API. |

---

## Interpolation

Mockondo's interpolation engine resolves `${...}` placeholders inside response bodies and headers at request time. Placeholders are organised into namespaces.

### `random.*` — random data

| Placeholder | Output |
|---|---|
| `${random.uuid}` | UUID v4 string, e.g. `"e7a9e2b4-5e6f-44a9-b812-bffb0db6c7c4"` |
| `${random.integer.100}` | Random integer in `[0, 100)`, e.g. `42` |
| `${random.double.10.5}` | Random float in `[0.0, 10.5)`, e.g. `7.2183` |
| `${random.string.20}` | Random 20-character alphanumeric string |
| `${random.name}` | Full name, e.g. `"John Doe"` |
| `${random.username}` | Username, e.g. `"john_doe"` |
| `${random.email}` | Email address, e.g. `"john@example.com"` |
| `${random.url}` | HTTP URL |
| `${random.phone}` | Phone number |
| `${random.lorem}` | Lorem ipsum sentence |
| `${random.jwt}` | Valid JWT token |
| `${random.date}` | Current UTC timestamp in ISO-8601 format |
| `${random.image.400x400}` | `"https://placehold.co/400x400"` |
| `${random.image.400x400.index}` | Placeholder image with current item index as text overlay |
| `${random.image.400x400.label}` | Placeholder image with `"label"` as text overlay |
| `${random.index}` | Current item index (set by the pagination engine) |

### `request.*` — values from the incoming request

| Placeholder | Description |
|---|---|
| `${request.url.query.page}` | Value of the `page` query parameter |
| `${request.url.path.0}` | First path segment (zero-based index) |
| `${request.header.authorization}` | Value of the `Authorization` header (case-insensitive) |
| `${request.body.field}` | Top-level field from the JSON request body |
| `${request.body.user.email}` | Nested field via dot notation |

### `customdata.*` — user-defined data lists

| Placeholder | Description |
|---|---|
| `${customdata.cities}` | First value in the `cities` list |
| `${customdata.random.cities}` | Random value from the `cities` list |
| `${customdata.cities.Jakarta}` | `"Jakarta"` if it exists in the list |

Define your data lists in the **Custom Data** panel (toolbar icon).

### `pagination.*` — pagination context

| Placeholder | Description |
|---|---|
| `${pagination.data}` | The generated array of items for the current page |
| `${pagination.request.url.query.page}` | The `page` query param, read in pagination context |

### `math.*` — arithmetic expressions

| Placeholder | Description |
|---|---|
| `${math.2+3}` | Evaluates to `5` |
| `${math.10*2+1}` | Evaluates to `21` |

Math expressions support nested interpolation, e.g. `${math.${request.url.query.page}*10}`.

---

## Response rules

Each endpoint can have one or more **conditional rules**. Rules are evaluated in order; the first matching rule overrides the default response.

**Condition targets:**

| Target | What it inspects |
|---|---|
| Query param | URL query string parameter |
| Request header | HTTP request header (case-insensitive) |
| Body field | JSON request body field (dot notation supported) |
| Route param | URL path segment (zero-based index) |

**Operators:** `equals`, `notEquals`, `contains`, `notContains`, `regexMatch`, `isEmpty`, `isNotEmpty`

**Logic:** `AND` (all conditions must match) or `OR` (any condition matches)

Each rule has its own response body, response headers, and HTTP status code.

---

## Pagination

Enable pagination on an endpoint via the **Pagination** tab in the response editor.

Configure:
- **Max items** — total number of items in the dataset
- **Limit param** — query parameter name for page size (e.g. `limit`)
- **Page param** — query parameter name for the page number (e.g. `page`)
- **Item template** — response body template for a single item; supports all `${random.*}` and `${request.*}` placeholders

The outer response body uses `${pagination.data}` to inject the generated array.

**Example:**

```json
// Item template (one item)
{
  "id": ${random.uuid},
  "name": ${random.name},
  "avatar": ${random.image.80x80.index}
}

// Outer response body
{
  "page": ${pagination.request.url.query.page},
  "total": 100,
  "data": ${pagination.data}
}
```

---

## Custom data

The **Custom Data** panel lets you define named lists of values that can be referenced from any response body or header via `${customdata.<key>}`.

**Use cases:** city names, product categories, status labels, or any static set of strings.

---

## Built-in HTTP client

The HTTP client tab lets you send requests directly from the app. You can:
- Choose HTTP method and enter any URL
- Add request headers and query parameters (with interpolation support)
- Send a JSON body
- View the raw response, status code, and headers
- Organise requests into groups with drag-and-drop reordering

---

## Technology stack

| Layer | Technology |
|---|---|
| UI | Flutter (Dart) |
| HTTP server | [Shelf](https://pub.dev/packages/shelf) + [shelf_router](https://pub.dev/packages/shelf_router) |
| State management | [GetX](https://pub.dev/packages/get) |
| Persistence | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| Fake data | [Faker](https://pub.dev/packages/faker) |
| Math evaluation | [math_expressions](https://pub.dev/packages/math_expressions) |
| Code editor | [re_editor](https://pub.dev/packages/re_editor) |

---

## Running locally

```bash
git clone https://github.com/<org>/mockondo.git
cd mockondo
flutter pub get
flutter run -d macos   # or windows / linux
```

Requires Flutter 3.13+ and Dart 3.7+.

---

## Running tests

```bash
flutter test
```

Unit tests cover the interpolation engine, model serialisation, routing rule evaluation, and utility functions.

---

## License

MIT License © 2025 — Mockondo Team
