-- The app database at schema version 1 (T18), as created by drift.
-- Used to test migrations from it; never edit.
CREATE TABLE "cached_products" ("ean" TEXT NOT NULL, "json" TEXT NOT NULL, "fetched_at" TEXT NOT NULL, PRIMARY KEY ("ean"));
CREATE TABLE "contribution_outbox" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "kind" TEXT NOT NULL, "payload" TEXT NOT NULL, "created_at" TEXT NOT NULL, "attempts" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL);
CREATE TABLE "scan_history" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "ean" TEXT NOT NULL, "scanned_at" TEXT NOT NULL);
