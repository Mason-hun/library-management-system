# Library Management System API

A NestJS + Prisma + PostgreSQL (hosted on Neon) backend service for a Library Management System.

---

## Repository Structure

The project follows a decoupled service architecture with the backend application housed inside the `api/` directory:

```
library-api/
├── README.md             # Project documentation and schema design rationale
├── .gitignore            # Git exclusion rules (safeguards .env and build files)
├── .env                  # Local environment file (never committed)
└── api/                  # Application root
    ├── .env.example      # Environment variable template with placeholders
    ├── package.json      # Dependencies and execution scripts
    ├── tsconfig.json     # TypeScript ESM compiler configuration
    ├── nest-cli.json     # NestJS CLI configuration
    ├── prisma7.config.ts # Prisma 7 configuration and seed runner
    ├── prisma/
    │   ├── schema.prisma # Data models (User, Genre, Book, Role enum)
    │   ├── seed.ts       # Idempotent database seed script
    │   └── migrations/   # Historical migration DDLs
    ├── src/
    │   ├── main.ts       # Application entry point
    │   ├── app.module.ts # Root NestJS application module
    │   ├── prisma/       # PrismaModule and PrismaService lifecycle management
    │   └── generated/    # Generated Prisma client output
    └── test/             # End-to-end and integration tests
```

---

## Schema Decisions

### Why `Book` References `Genre` Instead of Embedding It

In relational data modeling and domain-driven design, a central decision is whether to normalize reference entities like `Genre` or embed them directly (e.g., as a free-form string or JSON attribute on `Book`). In this architecture, `Genre` is modeled as an independent, normalized relation where each `Book` explicitly references a `Genre` record via `genreId` and Prisma's `@relation` attribute.

This design was chosen for several critical reasons:

1. **Relational Normalization and Single Source of Truth:**
   - Genres are distinct domain entities with their own metadata (such as `name` and `description`). Normalizing genres into their own table ensures that genre data is defined once and referenced consistently across the system.
   - If genre names were embedded as strings on `Book` records, updating a genre name (e.g., renaming "Science" to "Science & Technology") would require bulk-updating thousands of rows across the `Book` table, risking partial updates, table locks, and inconsistent states.

2. **Elimination of Data Redundancy and Typo Inconsistencies:**
   - Embedding text values introduces significant risk of typos, casing discrepancies (e.g., `"Sci-Fi"`, `"scifi"`, `"Science Fiction"`), and duplicates.
   - A dedicated `Genre` table enforces uniqueness on `Genre.name` at the database level (`@unique`), guaranteeing catalog-wide standardization.

3. **Query Optimization and Indexing:**
   - Relational foreign keys allow the database engine to maintain a b-tree index on `Book.genreId` (`@@index([genreId])`).
   - Querying books by genre operates as an integer-based index lookup rather than expensive full-table scans or text pattern matches on string columns.
   - Database joins between `Book` and `Genre` are compact, predictable, and performant.

4. **Referential Integrity and Deletion Safety:**
   - With an explicit Prisma relation (`@relation(fields: [genreId], references: [id], onDelete: Restrict)`), PostgreSQL enforces foreign key constraints at the storage engine level.
   - A genre cannot be accidentally deleted if books are still assigned to it (`onDelete: Restrict`), protecting the library catalog against orphaned records.

5. **Extensibility and Separation of Concerns:**
   - Modeling `Genre` as a first-class table enables future enhancements without schema breakage—such as adding hierarchical genres (parent/child categories), genre codes, localized translations, or librarian classification taxonomies.

---

## Getting Started

### Prerequisites
- Node.js (v20 or higher)
- npm or pnpm
- PostgreSQL instance (local or hosted Neon database)

### Environment Configuration
The backend application supports safe dual-location environment resolution:
1. It first checks `api/.env` if present.
2. It falls back to `../.env` (repository root).

To create a local configuration from the template:
```bash
cd api
cp .env.example .env
```
Update `.env` with your PostgreSQL database connection string (`DATABASE_URL`).

### Installation
From within the `api/` directory:
```bash
npm install
```

### Database Setup & Migrations
```bash
# Validate Prisma schema
npx prisma validate --config prisma7.config.ts

# Generate Prisma Client
npx prisma generate --config prisma7.config.ts

# Apply pending migrations
npx prisma migrate deploy --config prisma7.config.ts

# Run seed script
npm run seed
```

### Running the Application
```bash
# Development mode with hot-reload
npm run start:dev

# Production build & start
npm run build
npm run start:prod
```

### Running Tests & Quality Checks
```bash
# Unit tests
npm run test

# Type-aware linting
npm run lint

# E2E tests
npm run test:e2e
```
