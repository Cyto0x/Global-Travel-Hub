# Global Travel Hub - Prisma Data Layer

Prisma ORM schema for the AI travel platform.

## Files

| File | Purpose |
|------|---------|
| `schema.prisma` | Database schema (tables, relations, indexes) |
| `seed.ts` | Test data for development |
| `package.json` | Dependencies and scripts |
| `.env.example` | Environment variables template |

## Quick Setup

### 1. Install Dependencies

```bash
cd prisma
npm install
```

### 2. Setup Environment

```bash
cp .env.example .env
# Edit .env with your database URL
```

### 3. Run Migrations

```bash
# Create database tables
npx prisma migrate dev --name init

# Generate Prisma Client
npx prisma generate
```

### 4. Seed Data

```bash
npx prisma db seed
```

### 5. Open Studio (Database GUI)

```bash
npx prisma studio
```

## Available Commands

```bash
npm run db:migrate    # Create new migration
npm run db:push       # Push schema without migration
npm run db:seed       # Seed test data
npm run db:studio     # Open Prisma Studio
npm run db:reset      # Reset database
```

## Schema Overview

```
User
├── OAuthAccount
├── ChatSession
│   └── ChatMessage
├── Booking
│   └── BookingItem
│       ├── FlightBooking
│       └── HotelBooking
├── FlightSearchCache
├── HotelSearchCache
└── AnalyticsEvent
```

## Database Connection

### Local Development (Docker)

```
DATABASE_URL="postgresql://gth_user:gth_password@localhost:5432/global_travel_hub"
```

### With PgBouncer (Production)

```
DATABASE_URL="postgresql://gth_user:gth_password@localhost:6432/global_travel_hub"
DIRECT_URL="postgresql://gth_user:gth_password@localhost:5432/global_travel_hub"
```

## Team Integration

Backend developers use Prisma Client:

```typescript
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

// Example: Get user with bookings
const user = await prisma.user.findUnique({
  where: { id: 'user-id' },
  include: { bookings: true }
})
```
