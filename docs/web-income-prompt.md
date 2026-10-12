# Prompt: add income tracking to Buck Web

Paste everything below the line into a Claude Code session opened in `Buck-Web-Application/buck`.

---

Add **income tracking** to Buck Web so income can be recorded, shown in cash-flow figures, and kept in sync with the Buck mobile app. Both apps use the same Supabase project.

## Background

- `wallets.budget` is a wallet's **current balance**. Expenses subtract from it (`addExpenseWithWalletDeduction` in `src/utils/supabaseData.ts`). Income must **add** to it.
- The mobile app already reads and writes a new `public.incomes` table. It records income only through the `add_income_atomic` RPC. Web must use the same table, the same RPCs and the same formulas so both apps show identical numbers.
- Follow the repo's existing conventions: `CLAUDE.md`, `assertUuid`, design-preview mode (`isDesignPreviewMode`), and the `mapX` row mappers in `supabaseData.ts`.

## 1. Migration

Create `supabase/migrations/202610110002_incomes.sql` with the exact SQL from the mobile repo at `Buck-Mobile/docs/migrations/202610110002_incomes.sql`. The SQL is idempotent. It contains:

- table `public.incomes`: `id, user_id, wallet_id, source, amount numeric(14,2) > 0, description, received_on date, metadata, created_at, updated_at`
- index `(user_id, received_on desc)`, index on `wallet_id`, an `updated_at` trigger, and a trigger that checks the wallet belongs to the income's owner
- RLS policy "Incomes are manageable by owner" for `authenticated`; grants; replica identity full; added to the `supabase_realtime` publication
- `add_income_atomic(p_wallet_id, p_amount, p_source, p_description, p_received_on) returns jsonb`: `SECURITY INVOKER`, locks the wallet row, inserts the income and adds `amount` to `wallets.budget` in one transaction
- `delete_income_atomic(p_income_id) returns jsonb`: deletes the income and subtracts its amount from the wallet, never going below 0

Run `list_migrations` (Supabase MCP) or `supabase migration list` first. If `202610110002_incomes` is already applied, just commit the file so the repo matches the database. Otherwise apply it.

## 2. Data layer (`src/utils/supabaseData.ts`)

- Add a `BuckIncome` type `{ id, walletId, source, amount, description, date, createdAt }` and a `mapIncome` mapper. Parse `received_on` as a local calendar date, the same way expenses use `spent_on`.
- `listIncomes(userId, { since?: string })`: select from `incomes`, filter `user_id`, order by `received_on desc, created_at desc`, page past the 1000-row cap.
- `addIncome(userId, { walletId, amount, source, description, date })`: call `supabase.rpc('add_income_atomic', …)`. Never insert directly and then update the wallet separately.
- `deleteIncome(userId, incomeId)`: call `supabase.rpc('delete_income_atomic', { p_income_id })`.
- If the table or RPC is missing (PostgREST `PGRST205` / `PGRST202` / `42P01`), treat income as "not tracked" instead of crashing.
- Preview mode: return a small `previewIncomes` list, and make add/delete no-ops.
- Add `incomes` to whatever realtime subscription the dashboard uses (`subscribeUserTable`), so mobile entries appear live.

## 3. UI

- **Add Income form**, reachable from the wallet page and the home dashboard (next to the existing Add Expense controls). Fields:
  - Amount: required, > 0
  - Category: required; one of `Salary, Allowance, Freelance, Business, Investment, Gift, Other`. Mobile uses the same list.
  - Date: defaults to today; no future dates
  - Description: optional
- The form credits the **active wallet** (`getActiveWallet`). With no active wallet, show "Create or select a wallet first to add income." After saving, refresh the wallet balance and the cash-flow figures.
- **Income list** (wallet page, or a tab on expenses): recent incomes with source, date and amount, plus delete (uses `deleteIncome`). Delete needs a confirm dialog because it lowers the wallet balance.
- **Monthly cash flow** on the dashboard and statistics pages, using these formulas (identical to mobile `FinanceSnapshot`):
  - `monthIncome` = sum of `incomes.amount` where `received_on` is in the current local calendar month
  - `monthExpenses` = sum of `expenses.amount` where `spent_on` is in the current local calendar month
  - `netSavings` = `monthIncome − monthExpenses` (may be negative; show it in the expense colour)
  - `savedRate` = `monthIncome > 0 ? clamp((monthIncome − monthExpenses) / monthIncome, 0, 1) : 0`
  - deltas: the same values for the previous calendar month, shown as `+₱5,000 vs last mo.` / `-₱2,100 vs last mo.`
  - If income isn't tracked (table missing), show `₱0`, "Not tracked yet", and a neutral savings bar.
- Pass any AI advisor or forecast inputs that use cash flow the real `monthIncome` (e.g. `src/utils/aiInsightsGenerator.ts`, `src/app/api/advisor/route.ts`) instead of estimating income from wallet budgets.

## 4. Don't change

- Expense add/delete logic and wallet transfer (`transfer_funds_atomic`).
- Existing columns, policies and functions. The migration only adds new things.

## 5. Verify

- Typecheck, lint and the test suite pass. Add unit tests for the cash-flow formulas (month boundaries, negative net, no income, table missing).
- Manual check: add an income on web. The wallet balance rises by exactly that amount, and the mobile app's Home and Expenses screens update live. Then delete it; the balance goes back down.
- Run the Supabase security advisor after the migration. It should report no new findings for `incomes`.
