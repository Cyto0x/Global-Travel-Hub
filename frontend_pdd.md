# 🎨 Frontend Product Design Document (PDD)
## Global Travel Hub – MVP

---

## 1. Purpose

This Product Design Document (PDD) defines **how the Global Travel Hub frontend should look, behave, and feel**. It translates the PRD and Engineering Requirements into concrete UI/UX decisions so frontend work is consistent, scalable, and demo-ready.

Audience:
- Frontend engineers
- Backend engineers (API alignment)
- Product & Sales (demo expectations)

---

## 2. Design Principles

1. **Chat-First Experience**  
   The chat is the product. Everything else supports it.

2. **Action-Oriented UI**  
   The user should always know what to do next.

3. **Low Cognitive Load**  
   Minimal text, clear options, structured cards.

4. **Demo-Ready Polish**  
   Clean visuals, predictable flows, no dead ends.

---

## 3. Target Devices

- Desktop (Primary – Sales demos)
- Tablet (Secondary)
- Mobile (Responsive, not mobile-first for MVP)

---

## 4. Information Architecture

### Public
- Login Page

### Authenticated User
- Chat Interface
- Booking Confirmation View (inline / modal)

### Admin
- Admin Dashboard

---

## 5. Core Screens & UX

## 5.1 Authentication

### Login Screen

**Features:**
- Email login
- Google OAuth login
- Minimal branding

**UX Notes:**
- No registration complexity
- Errors must be human-readable

---

## 5.2 User Chat Interface (Primary Screen)

### Layout

- Header
  - App name
  - User avatar / logout

- Chat Window
  - Message bubbles (User / AI)
  - System messages

- Input Area
  - Text input
  - Send button

---

### Message Types

#### 1. User Message
- Right aligned
- Plain text

#### 2. AI Text Message
- Left aligned
- Supports markdown

#### 3. AI Option Cards (Critical)

Used for:
- Flight options
- Hotel options

Each card contains:
- Title (Airline / Hotel name)
- Key attributes (price, date, rating)
- CTA button: "Select"

---

### Interaction Flow

1. User sends message
2. UI immediately appends user bubble
3. Loading indicator appears
4. AI response streams or loads
5. Option cards rendered if present
6. User selects an option

---

## 5.3 Booking Confirmation UI

### Trigger
- After user confirms travel option

### Display
- Inline chat message OR modal

### Content
- Trip summary
- Flight details
- Hotel details
- Status badge: "Mock Booking"
- Confirmation ID

### CTA
- "Check your email for confirmation"

---

## 5.4 Admin Dashboard

### Layout

- Sidebar (optional)
- Main content area

### Metrics Cards
- Total Users
- Active Chat Sessions
- Bookings Generated

### Behavior
- Read-only
- Auto-refresh every X seconds

---

## 6. Component Breakdown

### Reusable Components
- ChatBubble
- OptionCard
- LoadingIndicator
- MetricCard
- Button

### Page Components
- LoginPage
- ChatPage
- AdminDashboardPage

---

## 7. State Management

### Tool
- TanStack Query

### Managed State
- Auth state
- Chat messages
- Chat session ID
- Loading / error states

---

## 8. API Contract Expectations

Frontend expects **structured JSON only**.

Example (Flight option):
```json
{
  "id": "flight_123",
  "type": "flight",
  "provider": "Google Flights",
  "price": 520,
  "currency": "USD",
  "departure": "AMM",
  "arrival": "DXB",
  "date": "2026-03-01"
}
```

No raw AI text parsing in frontend.

---

## 9. Error & Edge Case Handling

- API failure → friendly system message
- No results → suggest alternative dates
- Session expired → redirect to login

---

## 10. Accessibility & UX Quality

- Minimum contrast compliance
- Keyboard navigation support
- Click targets ≥ 44px

---

## 11. Performance Requirements

- First contentful paint ≤ 2s
- Chat response render ≤ 200ms after API return
- No blocking UI during loading

---

## 12. Out of Scope (Frontend MVP)

- Multi-language UI
- User profile editing
- Dark mode (optional v2)
- Notifications center

---

## 13. Handoff Notes

- Backend must provide stable JSON contracts
- Option card schemas must not change without notice
- Admin metrics API must be documented

---

**Status:** Frontend PDD v1 (MVP)

