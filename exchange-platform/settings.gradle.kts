// ==============================================================================
// Exchange Platform — Root Settings (Monorepo Glue)
//
// This file uses 'includeBuild' to treat nested services as independent
// Gradle builds that are part of this monorepo. This allows the Antigravity
// IDE to discover and index all services automatically.
// ==============================================================================

rootProject.name = "exchange-platform"

// Include independent services as composite builds
includeBuild("services/internal/notification-service")
includeBuild("services/internal/validation-engine")
