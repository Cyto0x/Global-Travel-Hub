# 📘 Product Requirements Document (PRD)
## Product: **Global Travel Hub (MVP)**

---

## 1. Product Overview

**Product Name:** Global Travel Hub  
**Type:** AI-powered Travel & Tourism Assistant  
**Stage:** MVP (Internal Sales + Demo Product)

### Problem Statement
Travel planning is fragmented across multiple platforms (flights, hotels, weather, flight status). Users want a **single intelligent interface** that can understand intent, fetch real-time data, and produce actionable results.

### Proposed Solution
Global Travel Hub is a **chat-based AI travel agent** that:
- Collects travel requirements conversationally
- Executes real actions (search, pricing, status checks)
- Displays structured, selectable options
- Generates professional mock booking confirmations

---

## 2. Goals & Success Metrics

### Business Goals
- Provide Sales with a **real, demo-ready product**
- Demonstrate Devorise full-stack + AI capability
- Reduce demo setup and preparation time

### Success Metrics (MVP)
- ⏱ End-to-end trip planning ≤ 2 minutes
- 🤖 Agent completes full flow autonomously
- 📊 Admin dashboard shows live usage
- 📩 Booking confirmation email delivered successfully

---

## 3. Target Users

### End User (Traveler)
- Wants fast and accurate travel options
- Interacts primarily via chat
- Expects real-time pricing and status

### Admin User
- Sales / Operations team
- Views analytics and usage data
- No booking edits in MVP

---

## 4. User Experience (UX)

### 4.1 Traveler User Flow
1. User logs in (Email / Google OAuth)
2. User opens chat interface
3. AI asks for missing information:
   - Destination
   - Dates
   - Preferences
4. AI fetches:
   - Flights
   - Hotels
   - Weather
5. AI displays selectable options
6. User confirms choice
7. AI generates mock booking confirmation
8. Confirmation is sent via email

### 4.2 Admin Flow
1. Admin logs in
2. Admin dashboard displays:
   - Total users
   - Active chat sessions
   - Bookings generated

---

## 5. Functional Requirements

### 5.1 Authentication
- Email login
- Google OAuth
- Managed via Auth0 or Firebase Auth

### 5.2 Chat Interface
- Real-time chat UI
- Supports streaming responses (optional)
- Displays rich option cards for flights/hotels

### 5.3 AI Agent (Core Requirement)

The agent must be **action-oriented**, not conversational-only.

Capabilities:
- Stateful conversation memory
- Missing-information detection
- Tool execution via LangGraph
- Deterministic decision flow

Powered by:
- FastAPI
- LangGraph
- Redis (memory & caching)

### 5.4 External Integrations

| Service | Purpose |
|------|------|
| SerpAPI | Weather & search |
| Google Flights | Flight pricing |
| Google Hotels | Hotel pricing |
| Amadeus API | Flight status |

### 5.5 Booking Confirmation
- Generated as HTML or PDF
- Includes:
  - User name
  - Trip details
  - Flight summary
  - Hotel summary
  - Status: "Mock Booking"
- Sent via email

### 5.6 Admin Dashboard
- Read-only analytics view
- Metrics:
  - Users count
  - Chat sessions
  - Booking confirmations generated

---

## 6. Non-Functional Requirements

### Security
- No API keys exposed to frontend
- OAuth token management
- Encrypted PII at rest
- Secure email delivery

### Performance
- Backend API response ≤ 2s (excluding external APIs)
- Chat latency ≤ 500ms (excluding AI reasoning)

### DevOps
- Dockerized microservices
- Docker Compose for local development
- Gitflow branching strategy
- Ngrok for demos

---

## 7. Technical Architecture (Summary)

**Frontend**
- React (Vite)
- Tailwind CSS
- TanStack Query

**Backend**
- FastAPI
- LangGraph
- Redis

**Database**
- PostgreSQL

**Infrastructure**
- Docker
- GitHub
- Ngrok

---

## 8. MVP Scope

### In Scope
- Chat-based travel planning
- Real-time flight & hotel data
- Flight status checking
- Mock booking confirmation
- Admin analytics dashboard

### Out of Scope
- Real payments
- Actual ticket booking
- Profile management
- Cancellations or refunds
- Multi-language support

---

## 9. Risks & Mitigation

| Risk | Mitigation |
|----|----|
| API rate limits | Caching & mock fallback |
| Agent hallucination | Tool-only execution |
| UI/backend mismatch | Early JSON contracts |
| Credential leakage | Pre-commit secret scanning |

---

## 10. Ownership

| Area | Owner |
|----|----|
| Product | Devorise |
| Frontend | Yazeed |
| Backend & AI | Mustafa, Omar |
| Travel APIs | Wesam |
| Data | Remas, Shroq, Fatema |
| Security | Nowwar, Beshtawi, Kraizem |

---

## 11. Milestones

| Phase | Target |
|----|----|
| Architecture Sign-off | Day 1 |
| Agent MVP | Day 3 |
| UI + Backend Integration | Day 4 |
| Demo-Ready Build | Day 5 |

---

**Status:** Draft v1 (MVP)

