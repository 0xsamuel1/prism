# Prism Contracts

Soroban contracts that give the explorer something real to inspect.

`showcase/` deliberately uses every storage durability, all three event data
formats, varied ABI values, authorization, a predictable contract error, and an
admin-only upgrade.

## Contracts

| Crate | What it exercises |
| --- | --- |
| [`showcase`](./showcase) | Instance, persistent, and temporary storage; typed map, vec, and single-value events; compound ABI values; a deliberate error; and admin-only Wasm upgrades. |

### What `showcase` exercises

- **Instance storage** — `admin` and a counter.
- **Persistent storage** — keyed notes plus standalone `Vec<i128>` and
  `Map<Symbol, String>` entries.
- **Temporary storage** — per-address session markers that expire on their own.
- **Events** — eight typed events. Most use map data, `AmountsTallied` uses vec
  data, and `CounterValue` uses single-value data.
- **ABI surface** — `u32`, `i128`, `Symbol`, `String`, `Address`, `Bytes`,
  `BytesN<32>`, `Vec<T>`, `Map<K, V>`, `Option<T>`, struct returns, and a
  contract enum.
- **Failure** — `boom()` always returns `Error::Deliberate`.
- **Upgrades** — `upgrade(new_wasm_hash)` swaps the contract's code for Wasm
  already uploaded to the network, keeping its address and storage. Only the
  admin can call it. This gives the indexer's `__wasm_hash__` upgrade tracking
  a contract we control (see [Upgrade recipe](#upgrade-recipe)).

## Local development

Run commands from the repository root. Each command below includes a typical
successful result; timing and compiler progress can differ by machine.

```bash
cd contracts
```

Example output:

```text
(no output; current directory is now contracts/)
```

```bash
cargo test
```

Example output:

```text
running 28 tests
test result: ok. 28 passed; 0 failed; 0 ignored
```

```bash
cargo fmt --all -- --check
```

Example output:

```text
(no output; exit status 0)
```

```bash
cargo clippy --all-targets -- -D warnings
```

Example output:

```text
Finished `dev` profile [unoptimized + debuginfo] target(s)
```

```bash
stellar contract build
```

Example output:

```text
ℹ️  Build Complete
```

The pinned Rust toolchain installs `wasm32v1-none`, rustfmt, and clippy. Tests
also write ledger snapshots to `showcase/test_snapshots/`; those snapshots are
committed so state changes are visible in review.

## Automated testnet deployment

The deployment script creates and funds `prism-showcase` when that identity is
missing, builds and deploys the WASM, initializes it, and invokes representative
storage and event functions.

```bash
./deploy-showcase-testnet.sh
```

Example output:

```text
Creating and funding Stellar identity 'prism-showcase' on testnet...
Building the showcase contract...
Deploying the showcase contract...
Initializing and generating sample activity...
Contract ID: CAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
Prism URL: https://prism-gules.vercel.app/contract/CAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
```

Override `SOURCE_ACCOUNT`, `NETWORK`, or `PRISM_URL` when needed. The final URL
is ready to open at `/contract/<CONTRACT_ID>` after network ingestion catches
up.

## Manual testnet recipe

The following is the same flow broken into inspectable steps.

```bash
stellar keys generate --global alice --network testnet --fund
```

Example output:

```text
✅ Funded account alice on testnet
```

```bash
stellar contract build
```

Example output:

```text
ℹ️  Build Complete
```

```bash
stellar contract deploy \
  --wasm target/wasm32v1-none/release/prism_showcase.wasm \
  --source alice --network testnet
```

Example output:

```text
CAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
```

Save that value as `CONTRACT_ID`, then initialize the contract:

```bash
stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- init --admin "$(stellar keys address alice)"
```

Example output:

```text
null
```

Create instance storage plus map-format and single-value events:

```bash
stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- bump --by 7
```

Example output:

```text
7
```

Create keyed persistent storage and a map-format event with two indexed topics:

```bash
stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- put_note --author "$(stellar keys address alice)" --name hello --body "first revision"
```

Example output:

```text
1
```

Create persistent Vec and Map entries:

```bash
stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- store_collections --values '[1,2,3]' \
  --labels '{"environment":"testnet","purpose":"showcase"}'
```

Example output:

```text
null
```

Emit a vec-format event:

```bash
stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- tally --amounts '[10,20,12]'
```

Example output:

```text
42
```

Create temporary storage:

```bash
stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- start_session --who "$(stellar keys address alice)" --ledgers 200
```

Example output:

```text
null
```

Finally, create a failed invocation for Prism's error renderer:

```bash
stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- boom
```

Expected output (this command intentionally exits non-zero):

```text
error: HostError: Error(Contract, #5)
```

## Upgrade recipe

Upgrading replaces the contract's code while keeping its address and storage,
which is what Prism's `__wasm_hash__` tracking watches for. This continues
from the manual recipe above, with `CONTRACT_ID` set and `alice` as admin.

Build a second Wasm with different bytes. The `release-with-logs` profile keeps
debug assertions, so it produces a different hash without any code change (any
real code change works too):

```bash
stellar contract build --profile release-with-logs
```

Example output:

```text
ℹ️  Build Complete
```

Upload it. Uploading installs the code on the network without deploying a new
contract, and prints its hash:

```bash
stellar contract upload \
  --wasm target/wasm32v1-none/release-with-logs/prism_showcase.wasm \
  --source alice --network testnet
```

Example output:

```text
6a1c3b0f9e5d2c4b8a7f6e5d4c3b2a1908f7e6d5c4b3a29180f7e6d5c4b3a291
```

Save that value as `NEW_WASM_HASH`, then upgrade as the admin:

```bash
stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- upgrade --new_wasm_hash "$NEW_WASM_HASH"
```

Example output:

```text
null
```

The call emits an `upgraded` contract event with the new hash, and the
network records its own system event for the executable change. Check that the
contract now runs the new code: the SHA-256 of the fetched Wasm is the
contract's Wasm hash.

```bash
stellar contract fetch --id "$CONTRACT_ID" --network testnet --out-file current.wasm
shasum -a 256 current.wasm
```

Example output:

```text
6a1c3b0f9e5d2c4b8a7f6e5d4c3b2a1908f7e6d5c4b3a29180f7e6d5c4b3a291  current.wasm
```

Any other account is refused, because `upgrade` requires the admin's
authorization:

```bash
stellar keys generate --global bob --network testnet --fund
stellar contract invoke --id "$CONTRACT_ID" --source bob --network testnet \
  -- upgrade --new_wasm_hash "$NEW_WASM_HASH"
```

Expected output (the invoke intentionally exits non-zero; wording varies by CLI
version):

```text
error: HostError: Error(Auth, InvalidAction)
```

Upgrading to a hash that was never uploaded also fails, and the contract keeps
its current code. Once the indexer has caught up, the contract page at
`/contract/<CONTRACT_ID>` shows the new Wasm hash.
