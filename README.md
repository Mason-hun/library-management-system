# Library Management System

A backend data-layer implementation for a Library Management System, built with **NestJS**, **Prisma ORM 7**, and **PostgreSQL** (hosted on Neon).

This project models users and catalog data, enforces a one-to-many relationship between genres and books, and includes a repeatable seed script for development data.

## Project Structure

```text
library-management-system/
├── README.md
├── .gitignore
└── api/
    ├── .env.example
    ├── package.json
    ├── prisma7.config.ts
    ├── prisma/
    │   ├── schema.prisma
    │   ├── seed.ts
    │   └── migrations/
    └── src/
        ├── main.ts
        ├── app.module.ts
        └── prisma/
            ├── prisma.module.ts
            └── prisma.service.ts
```

## Data Model

The Prisma schema defines:

- **User** — a user account with a unique email and a `Role` value.
- **Role** — an enum containing `PATRON` and `LIBRARIAN`; new users default to `PATRON`.
- **Genre** — a uniquely named catalog category with an optional description.
- **Book** — a catalog item with a unique ISBN and a required reference to one genre.

### Book–Genre relationship

The relationship is **one-to-many**:

- A genre can contain many books.
- Each book belongs to exactly one genre.
- `Book.genreId` is a required foreign key referencing `Genre.id`.
- The relation uses `onDelete: Restrict`, preventing deletion of a genre while books still reference it.

## Schema Decisions

### Why does Book reference Genre instead of embedding it?

A genre is a reusable catalog concept with its own identity and metadata. Modeling it as a separate table avoids repeating genre names in every book record and gives the database one authoritative place to maintain genre information.

The `Book.genreId` foreign key and Prisma `@relation` provide several benefits:

1. **Consistency:** `Genre.name` is unique, so books reference a canonical genre instead of storing slightly different text values such as `Science`, `science`, or `Sci`.
2. **Less duplication:** Updating a genre's name or description happens once in the Genre record rather than across many Book records.
3. **Referential integrity:** PostgreSQL enforces that every book references an existing genre. The restrictive delete behavior protects genres that are still in use.
4. **Clear querying:** The foreign key and its index support filtering books by genre and joining book data with genre metadata.
5. **Extensibility:** Genre-specific attributes can be added without changing every book record.

### Prisma compared with a document database

Prisma models this catalog through explicit relational models, scalar fields, and foreign-key relations. The database enforces the relationship between `Book` and `Genre`. In a document database, the same domain could instead be represented with embedded genre data inside book documents or with references between separate documents. Embedding can make some reads convenient, but repeating genre details across books introduces update and consistency concerns. For a catalog where genres are shared entities, a normalized relational model is a natural fit.

## Seed Data

The seed script inserts or updates:

| Genre | Books |
|---|---:|
| Fiction | 4 |
| Philosophy | 5 |
| Science | 4 |
| History | 2 |
| **Total** | **15** |

The script uses Prisma `upsert` operations keyed by unique genre names and book ISBNs, making repeated runs safe for the included seed records.

## Technology

- Node.js
- NestJS
- TypeScript
- Prisma ORM 7 with the PostgreSQL driver adapter
- PostgreSQL
- Neon (hosted PostgreSQL)

## Getting Started

### Prerequisites

- Node.js 20 or later
- npm
- A PostgreSQL database (local PostgreSQL or a hosted instance such as Neon)

### 1. Clone the repository

```bash
git clone https://github.com/Mason-hun/library-management-system.git
cd library-management-system/api
```

### 2. Configure the database connection

Create an environment file from the example:

**PowerShell**
```powershell
Copy-Item .env.example .env
```

**macOS / Linux**
```bash
cp .env.example .env
```

Set `DATABASE_URL` in `api/.env` to your PostgreSQL connection string. The committed `.env.example` contains placeholders only. Never commit real database credentials.

The Prisma configuration, seed script, and Prisma service load environment variables from `api/.env`; they also support the repository-root `.env` fallback used during development.

### 3. Install dependencies

Run from the `api/` directory:

```bash
npm install
```

### 4. Validate, generate, migrate, and seed

The project uses a custom Prisma 7 configuration file, so include it in Prisma CLI commands:

```bash
npx prisma validate --config prisma7.config.ts
npx prisma generate --config prisma7.config.ts
npx prisma migrate deploy --config prisma7.config.ts
npm run seed
```

These commands validate the schema, generate the Prisma Client, apply committed migrations to the configured database, and insert the sample catalog data. Run migrations only against a database you intend to update.

### 5. Run the NestJS application

Development mode:

```bash
npm run start:dev
```

Build and run:

```bash
npm run build
npm run start:prod
```

The application listens on port `3000` by default. Set `PORT` in your environment to override it.

## Quality Checks

From the `api/` directory:

```bash
npm run lint
npm test
npm run test:e2e
npm run build
```

## Environment and Security

- Keep real credentials in an untracked `.env` file.
- Use `.env.example` as the safe configuration template.
- Do not commit database URLs, passwords, generated build output, or `node_modules`.
