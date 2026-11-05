BEGIN;

-- Step 1: Create Role Enum
CREATE TYPE "Role" AS ENUM ('PATRON', 'LIBRARIAN');

-- Step 2: Add role column to User with default 'PATRON'
ALTER TABLE "User" ADD COLUMN "role" "Role" NOT NULL DEFAULT 'PATRON';

-- Step 3: Archive all existing Many-to-Many relationships into legacy backup table
-- This guarantees that all historical associations are preserved before table removal.
CREATE TABLE "_BookToGenre_legacy_backup" AS
SELECT
    "A" AS "bookId",
    "B" AS "genreId",
    CURRENT_TIMESTAMP AS "archivedAt"
FROM "_BookToGenre";

-- Step 3b: Strengthened pair-by-pair verification
-- Verifies row-count equality AND ensures every original (A, B) pair exists in the backup table.
DO $$
DECLARE
    source_count INTEGER;
    backup_count INTEGER;
    missing_pairs_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO source_count FROM "_BookToGenre";
    SELECT COUNT(*) INTO backup_count FROM "_BookToGenre_legacy_backup";

    IF source_count <> backup_count THEN
        RAISE EXCEPTION 'Legacy backup row-count verification failed: source _BookToGenre has % rows, but backup table has % rows', source_count, backup_count;
    END IF;

    -- Pair-by-pair comparison: check if any (A, B) pair in source is missing from backup
    SELECT COUNT(*) INTO missing_pairs_count
    FROM "_BookToGenre" s
    WHERE NOT EXISTS (
        SELECT 1
        FROM "_BookToGenre_legacy_backup" b
        WHERE b."bookId" = s."A" AND b."genreId" = s."B"
    );

    IF missing_pairs_count > 0 THEN
        RAISE EXCEPTION 'Legacy backup pair verification failed: % pair(s) from _BookToGenre are missing in _BookToGenre_legacy_backup', missing_pairs_count;
    END IF;
END $$;

-- Step 4: Add genreId column to Book as nullable initially for backfill
ALTER TABLE "Book" ADD COLUMN "genreId" INTEGER;

-- Step 5: Explicitly map every existing Book to its intended primary Genre using unique ISBN

-- 5a. Explicit approved primary assignments:
-- The Alchemist (9780061122415) -> Fiction
UPDATE "Book"
SET "genreId" = (SELECT "id" FROM "Genre" WHERE "name" = 'Fiction' LIMIT 1)
WHERE "isbn" = '9780061122415';

-- 1984 (9780451524935) -> Fiction
UPDATE "Book"
SET "genreId" = (SELECT "id" FROM "Genre" WHERE "name" = 'Fiction' LIMIT 1)
WHERE "isbn" = '9780451524935';

-- Siddhartha (9780553208849) -> Philosophy
UPDATE "Book"
SET "genreId" = (SELECT "id" FROM "Genre" WHERE "name" = 'Philosophy' LIMIT 1)
WHERE "isbn" = '9780553208849';

-- 5b. Remaining explicit assignments matched strictly by unique ISBN:
-- Fiction:
-- The Name of the Wind (9780756404741)
-- Dune (9780441172719)
UPDATE "Book"
SET "genreId" = (SELECT "id" FROM "Genre" WHERE "name" = 'Fiction' LIMIT 1)
WHERE "isbn" IN ('9780756404741', '9780441172719');

-- Philosophy:
-- Meditations (9780812968255)
-- The Republic (9780140449143)
-- The Kybalion (9781585420590)
-- Beyond Good and Evil (9780140449235)
UPDATE "Book"
SET "genreId" = (SELECT "id" FROM "Genre" WHERE "name" = 'Philosophy' LIMIT 1)
WHERE "isbn" IN ('9780812968255', '9780140449143', '9781585420590', '9780140449235');

-- Science:
-- Cosmos (9780345539434)
-- A Brief History of Time (9780553380163)
-- The Selfish Gene (9780198788607)
-- The Gene: An Intimate History (9781476733500)
UPDATE "Book"
SET "genreId" = (SELECT "id" FROM "Genre" WHERE "name" = 'Science' LIMIT 1)
WHERE "isbn" IN ('9780345539434', '9780553380163', '9780198788607', '9781476733500');

-- History:
-- Sapiens: A Brief History of Humankind (9780062316097)
-- Guns, Germs, and Steel (9780393317558)
UPDATE "Book"
SET "genreId" = (SELECT "id" FROM "Genre" WHERE "name" = 'History' LIMIT 1)
WHERE "isbn" IN ('9780062316097', '9780393317558');

-- Step 5c: Fail-fast verification: Ensure every single existing book was mapped to a valid genre.
-- If any book has an unmapped genre (or if a Genre record was missing from Genre table),
-- abort the migration with an explicit error detailing the affected books.
DO $$
DECLARE
    unmapped_count INTEGER;
    unmapped_details TEXT;
BEGIN
    SELECT COUNT(*), string_agg("title" || ' (ISBN: ' || "isbn" || ')', ', ')
    INTO unmapped_count, unmapped_details
    FROM "Book"
    WHERE "genreId" IS NULL;

    IF unmapped_count > 0 THEN
        RAISE EXCEPTION 'Migration aborted: % book(s) have no valid genre mapping: %', unmapped_count, unmapped_details;
    END IF;
END $$;

-- Step 6: Enforce NOT NULL, Index, and Foreign Key Constraint on Book.genreId
ALTER TABLE "Book" ALTER COLUMN "genreId" SET NOT NULL;

CREATE INDEX "Book_genreId_idx" ON "Book"("genreId");

ALTER TABLE "Book" ADD CONSTRAINT "Book_genreId_fkey"
    FOREIGN KEY ("genreId") REFERENCES "Genre"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Step 7: Drop foreign keys and remove legacy join table
ALTER TABLE "_BookToGenre" DROP CONSTRAINT IF EXISTS "_BookToGenre_A_fkey";
ALTER TABLE "_BookToGenre" DROP CONSTRAINT IF EXISTS "_BookToGenre_B_fkey";
DROP TABLE "_BookToGenre";

COMMIT;
