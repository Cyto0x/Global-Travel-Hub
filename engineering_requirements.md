# 🛠️ Engineering Requirements
## Global Travel Hub – MVP

---

## 1️⃣ Backend Engineering Requirements

### 1.1 Scope
The Backend is responsible for orchestration, AI execution, integrations, security enforcement, and data persistence.

### 1.2 Tech Stack
- FastAPI (async)
- LangGraph (AI orchestration)
- Redis (state + caching)
- PostgreSQL (primary DB)
- Docker

### 1.3 Core Responsibilities
- Expose REST APIs for frontend consumption
- Orchestrate AI agent flows
- Execute external API calls (Flights, Hotels, Status)
- Manage user sessions and memory
- Generate booking confirmations
- Trigger email delivery

### 1.4 Required Services & Modules

#### API Layer
- `/auth/verify` – token validation (Auth0/Firebase)
- `/chat/start` – start chat session
- `/chat/message` – send message to agent
- `/chat/state/{session_id}` – retrieve conversation state
- `/admin/metrics` – admin analytics

#### AI Agent Engine
- LangGraph-based state machine
- States:
  - Collect Destination
  - Collect Dates
  - Collect Preferences
  - Fetch Flights
  - Fetch Hotels
  - Fetch Weather
  - Display Options
  - Confirm Booking
  - Generate Confirmation

#### Integrations
- SerpAPI: Weather & search
- Google Flights / Hotels: pricing
- Amadeus API: flight status

#### Caching
- Redis used for:
  - Conversation memory
  - API response caching
  - Rate-limit protection

### 1.5 Non-Functional Requirements
- API response ≤ 2s (excluding third-party latency)
- Deterministic agent behavior (no hallucinated outputs)
- Tool-only execution for external data

---

## 2️⃣ Frontend Engineering Requirements

### 2.1 Scope
Frontend provides the user-facing chat interface and admin dashboard.

### 2.2 Tech Stack
- React (Vite)
- Tailwind CSS
- TanStack Query
- Auth0 or Firebase SDK

### 2.3 Core Views

#### User Chat View
- Login (Email / Google OAuth)
- Chat interface
- Streaming responses (optional)
- Option cards:
  - Flights
  - Hotels
- Selection + confirmation UI

#### Admin Dashboard
- Metrics cards:
  - Total users
  - Active sessions
  - Bookings generated
- Read-only

### 2.4 State Management
- TanStack Query for:
  - Chat messages
  - Agent responses
  - Real-time updates

### 2.5 API Contract Requirements
Frontend must rely only on:
- Structured JSON responses
- No direct calls to external travel APIs

### 2.6 Non-Functional Requirements
- First load ≤ 2s
- Mobile-responsive layout
- Graceful error states

---

## 3️⃣ Data Engineering Requirements

### 3.1 Scope
Design and maintain a scalable, analytics-ready data layer.

### 3.2 Tech Stack
- PostgreSQL
- SQLAlchemy or Prisma
- Docker

### 3.3 Core Entities

#### Users
- id
- email
- auth_provider
- created_at

#### Chat Sessions
- id
- user_id
- started_at
- ended_at

#### Chat Messages
- id
- session_id
- role (user/agent)
- content
- timestamp

#### Flight Cache
- id
- route
- provider
- response_json
- cached_at

#### Booking Records
- id
- user_id
- session_id
- summary_json
- created_at

### 3.4 Initialization
- `init.sql` must:
  - Create all tables
  - Seed dummy users
  - Seed dummy flight data

### 3.5 Analytics Support
- Schema must support:
  - Usage aggregation
  - Time-based queries
  - Admin dashboard metrics

### 3.6 Non-Functional Requirements
- Indexed foreign keys
- JSON fields for flexible API responses
- Backward-compatible schema changes

---

## 4️⃣ Cross-Team Constraints

- Schema changes must be announced
- API contracts must be versioned
- No secrets committed to repo
- Docker Compose is the single source of truth

---

**Status:** Engineering Requirements v1

