# Development Process

## Trunk Based Development

We have adopted a **Trunk Based Development** pipeline. This means that:

-   **Main Branch**: The `main` branch is the single source of truth and is always in a deployable state.
-   **No Long-Lived Branches**: We avoid checking out long-lived development branches.
-   **Continuous Integration**: Developers merge code into the trunk frequently (at least daily).

## Feature Branches

While we merge frequently, we use **Short-Lived Feature Branches** for specific tasks:

-   **Lifespan**: Feature branches must be very short-lived. The maximum lifespan is **1-2 days**.
-   **Scope**: Branches should be small and focused on a single logical change.
-   **Review**: All branches must pass a **Merge Request (MR)** review before merging to `main`.
-   **Deletion**: Branches are automatically deleted upon merge.

## Workflow

1.  **Checkout**: Create a new branch from `main`. `git checkout -b feature/my-cool-feature`
2.  **Commit**: Make focused, small commits.
3.  **Push**: Push to origin.
4.  **MR**: Open a Merge Request in GitLab.
5.  **Merge**: Squash and merge into `main` after approval via GitLab Pipeline success.
