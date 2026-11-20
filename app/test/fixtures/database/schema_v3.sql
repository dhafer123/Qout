-- The app database at schema version 3 (T39), as created by drift.
-- Used to test migrations from it; never edit.
CREATE TABLE "cached_products" ("ean" TEXT NOT NULL, "json" TEXT NOT NULL, "fetched_at" TEXT NOT NULL, PRIMARY KEY ("ean"));
CREATE TABLE "contribution_outbox" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "kind" TEXT NOT NULL, "client_id" TEXT NOT NULL UNIQUE, "payload" TEXT NOT NULL, "created_at" TEXT NOT NULL, "state" TEXT NOT NULL DEFAULT 'waiting', "next_attempt_at" TEXT NULL, "attempts" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL);
CREATE TABLE "local_profile" ("id" INTEGER NOT NULL, "onboarding_completed_at" TEXT NOT NULL, "sex" TEXT NULL, "age" INTEGER NULL, "age_entered_at" TEXT NULL, "height_cm" REAL NULL, "weight_kg" REAL NULL, "pal" TEXT NULL, "allergens" TEXT NOT NULL DEFAULT '[]', "avoided_additives" TEXT NOT NULL DEFAULT '[]', PRIMARY KEY ("id"));
CREATE TABLE "scan_history" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "ean" TEXT NOT NULL, "scanned_at" TEXT NOT NULL);
