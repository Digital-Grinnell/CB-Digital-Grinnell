# Human History

## Purpose

Use this append-only log for decisions, approvals, handoffs, and operational changes made by project contributors. Keep credentials and other secrets out of this repository; store them in approved secret-management systems instead.

## Entry Format

```markdown
### YYYY-MM-DD - Short title

- Decision or action:
- Owner:
- Context or follow-up:
```

## History

### 2026-09-02 - Azure Blob deployment access

- Decision or action: Configured the `digitalgrinnell` storage account for static website hosting and granted the current project operator `Storage Blob Data Contributor` at account scope.
- Owner: Digital Grinnell project operator.
- Context or follow-up: Use Azure AD login locally. Store any GitHub Actions SAS token only as the `SAS_TOKEN` repository secret, without a leading `?`.

### 2026-09-02 - Local Azure CLI configuration

- Decision or action: Added a private `.env` workflow for Azure Storage CLI commands using Azure AD login rather than a local account key or SAS token.
- Owner: Digital Grinnell project operator.
- Context or follow-up: Source `.env` in a terminal before running `az storage` commands. `.env.example` is the tracked, non-secret reference file.

