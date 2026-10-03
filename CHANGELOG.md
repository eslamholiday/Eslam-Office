# Eslam Money 1.2.1 (2003)

- Eight compact colored count/action cards below the financial overview: tickets, visas, hotels, passengers, customers, issuing companies, settlements, expenses. Each opens its corresponding creation form.
- Configurable electronic transfer account in office identity and exported statements, with an independent visibility setting. Default: 9645239113.
- Seeds 13 personal expense categories and their dependent subcategories once, for existing and new installations. Preserves existing records and custom categories.
- New expenses default to personal; selecting a seeded personal category marks the expense personal. Personal expenses retain the existing exclusion from office net profit.
- Keeps legacy free-text subcategories when editing; clears the subcategory when selecting another category.
- Fixes an invalid optional expense field in the visa form that could crash opening the form.
- Keeps the Android package, signing key, database name, and attachment paths for in-place installation over 1.2.0.

# Eslam Money 1.2.0 (2002)

Built from Eslam Office source at 62aaff18527f6a48c4121aab2a45fb4688374039.

- Retains `com.eslamholiday.eslam_office`, the original signing key, `eslam_office.db`, and attachment locations. Original supplied APK has versionCode 2001.
- Four home financial cards show USD and IQD separately; supplier balances open per supplier. Bottom navigation is Home, Customers, Statements, Settings.
- Services are entered from customer/supplier accounts. Home shortcuts open passengers, suppliers, expenses, movements, review, and about.
- Ticket/change is a descriptive field; changes keep ticket math without a reference to another ticket.
- Customer-owned passenger selection supports multiple passengers; passenger count and monetary quantities are explicit and separately visible.
- Removes family navigation and family fields while preserving historical payloads on upgrade.
- Normalizes Iraqi phone inputs; initializes zero-value money/rate inputs as blank.
- Adds review before posting, save-and-add-another, customer summaries, quick statements, grouped account movements and account deletion with atomic ledger cleanup.
- Expense allocation balance is derived from net service profit after refunds plus manual funding minus all expenses. Funding does not create profit. This is not a cash-on-hand balance.
- Adds expense categories/subcategories, date-range expense statements, a review center, and links from profit reports to source operations.
- Adds payment-method defaults and configurable statement columns, passenger names, quantities, notes, contact details and footer.
- Existing app icon retained pending the user's logo choice; no arbitrary logo selection was imposed.

Validation: domain/store/PDF/widget tests, including v1 database migration, isolated currencies, atomic account removal, derived expense balance, posting review cancellation/approval, and narrow phone layouts. No physical Samsung device test was available.
