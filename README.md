
# 🐊 Mockondo

**A Customizable Mock Server for Frontend Developers — No Coding Required.**

Mockondo is a **no-code mock server application** designed to help **frontend developers** easily create and test APIs without writing a single line of backend code.  
With an intuitive interface, powerful simulation features, and multi-project support, Mockondo accelerates your frontend workflow with realistic and flexible mock data.

----------

## 🚀 Key Features
| Feature                           | Description                                                        |
|-----------------------------------|--------------------------------------------------------------------|
| **HTTP Server**                   | Run a local mock server on any custom port.                        |
| **Pagination Simulation (Page-Based)** | Simulate paginated responses using `page` and `limit` parameters. |
| **Delay Response**                | Add artificial delay to test loading states.                       |
| **Multiple Projects**             | Manage multiple mock API projects in one place.                    |
| **Proxy URL**                     | Forward unmatched requests to a real API.                          |
| **Random Response**               | Generate dynamic mock data with random interpolation.              |

----------

## 🧩 Coming Soon

- [x] **Pagination Simulation (Offset & Cursor-Based)**
- [x] **Advanced Conditional Rules for Responses**
- [x] **Export & Import Project Files**
- [x] **WebSocket Mock Simulation**

    

----------

## 🧠 Random Interpolation System

Mockondo supports **random interpolation** to make mock responses more dynamic and lifelike.  
Use placeholders like `${random.integer.100}` or `${random.image.400x400.text}` inside your mock responses.

### 🎲 Available Interpolations
| Interpolation                     | Description                                    | Example Output                                      |
|-----------------------------------|------------------------------------------------|-----------------------------------------------------|
| `${random.index}`              | Returns the current data index                 | `5`                                                 |
| `${random.integer.100}`        | Random integer between 0–99                    | `42`                                                |
| `${random.double.10.0}`        | Random floating-point number up to a given max | `7.2183`                                            |
| `${random.string.20}`          | Random string of 20 characters                 | `"z8gPDk31MhsY9qZwUXfP"`                            |
| `${random.uuid}`               | Random UUID v4                                 | `"e7a9e2b4-5e6f-44a9-b812-bffb0db6c7c4"`            |
| `${random.image.400x400}`      | Placeholder image                              | `"https://placehold.co/400x400"`                    |
| `${random.image.400x400.index}`| Image with text based on index                 | `"https://placehold.co/400x400?text=Item+5"`        |
| `${random.image.400x400.text}` | Image with custom text                         | `"https://placehold.co/400x400?text=text"`          |


----------

## 🔁 Pagination Interpolation
Mockondo provides pagination-related interpolations to simulate realistic paginated responses that adapt to request parameters.

| Interpolation                              | Description                                     | Example |
|---------------------------------------------|-------------------------------------------------|----------|
| `${pagination.data}`                     | Returns data for the current page               | –        |
| `${pagination.request.url.query.page}`   | Gets the `page` parameter from the request URL  | `2`      |

**Example usage:**
```json
{
  "page": ${pagination.request.url.query.page},
  "data": ${pagination.data}
}
```

----------

## 🌐 Request Interpolation
Request interpolation allows you to dynamically use request parameters (like URL queries) inside your mock responses.

| Interpolation                 | Description                                   | Example |
|-------------------------------|-----------------------------------------------|----------|
| `${request.url.query.page}` | Reads the `page` query parameter from the URL | `3`      |

**Example request:**
GET /api/items?page=3


**Mock response:**
```json
{
  "current_page": ${request.url.query.page}
}
```

----------

## ⚙️ Technology Stack

-   **Dart** + **Shelf** for the mock HTTP server
    
-   **JSON-based configuration**
    
-   **Custom interpolation engine**
    

----------

## 🧪 Example Use Case


Suppose a frontend developer wants to simulate a paginated API at `/products?page=1`.  
They can define a mock response like this:

```json
{
  "page": ${request.url.query.page},
  "total": 50,
  "products": [
    {
      "id": ${random.uuid},
      "name": ${random.string.10},
      "price": ${random.integer.1000},
      "thumbnail": ${random.image.200x200.index}
    }
  ]
}
```

----------

## 🗺️ Roadmap

-   HTTP Server
    
-   Delay Response
    
-   Random Data Interpolation
    
-   Offset Pagination
    
-   Cursor Pagination
    
-   WebSocket Mock
    
-   Export & Import
    
-   Conditional Response Rules
    

----------

## 💡 Mission

> To make frontend development faster and more efficient by removing the need for backend setup during UI development.

Mockondo lets developers focus on **UI and UX**, while providing **realistic and flexible mock data** — all without coding.

----------

## 📜 License

MIT License © 2025 — **Mockondo Team**