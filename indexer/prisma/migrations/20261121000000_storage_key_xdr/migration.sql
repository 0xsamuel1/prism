ALTER TABLE "StorageChange" ADD COLUMN "keyXdr" TEXT NOT NULL DEFAULT '';
UPDATE "StorageChange" SET "keyXdr" = "keyDisplay" WHERE "keyXdr" = '';
DROP INDEX IF EXISTS "StorageChange_contractId_keyDisplay_durability_ledger_idx";
CREATE INDEX "StorageChange_contractId_keyXdr_durability_ledger_idx" ON "StorageChange"("contractId", "keyXdr", "durability", "ledger");
CREATE UNIQUE INDEX "StorageChange_txHash_contractId_keyXdr_durability_changeType_key" ON "StorageChange"("txHash", "contractId", "keyXdr", "durability", "changeType");
