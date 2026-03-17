-- ==================================================================================
-- SERVICE: NOTIFICATION SERVICE
-- Schema initialisation for notification auditing, distribution list management,
-- and user-level notification tracking.
--
-- Follows the same Flyway versioning convention as the platform baseline migrations.
-- ==================================================================================

-- ==========================================
-- DOMAIN: NOTIFICATION AUDIT LOG
-- Immutable record of every notification
-- dispatch attempt and its outcome.
-- ==========================================
CREATE TABLE notification_audits (
    notification_id     UUID        PRIMARY KEY,
    channel             VARCHAR(20) NOT NULL
                            CHECK (channel IN ('EMAIL', 'SMS', 'WHATSAPP', 'SIGNAL', 'BLUESKY', 'X')),
    recipient_type      VARCHAR(10) NOT NULL DEFAULT 'SINGLE'
                            CHECK (recipient_type IN ('SINGLE', 'LIST')),
    destination         VARCHAR(255),           -- Email address or phone; NULL for LIST sends
    list_id             UUID,                   -- FK to distribution_lists; NULL for SINGLE sends
    source              VARCHAR(100),           -- Originating service / user
    template_id         VARCHAR(100) NOT NULL,
    status              VARCHAR(50)  NOT NULL,  -- e.g. DELIVERED, FAILED_NETWORK, REJECTED
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Exactly one of destination or list_id must be present
    CONSTRAINT chk_recipient_target CHECK (
        (recipient_type = 'SINGLE' AND destination IS NOT NULL AND list_id IS NULL) OR
        (recipient_type = 'LIST'   AND list_id IS NOT NULL AND destination IS NULL)
    )
);

CREATE INDEX idx_audit_channel    ON notification_audits(channel);
CREATE INDEX idx_audit_status     ON notification_audits(status);
CREATE INDEX idx_audit_created_at ON notification_audits(created_at DESC);
CREATE INDEX idx_audit_list_id    ON notification_audits(list_id) WHERE list_id IS NOT NULL;

-- ==========================================
-- DOMAIN: DISTRIBUTION LISTS
-- Internal representation of an SFMC
-- Data Extension. The external_key is the
-- SFMC DataExtensionKey used for sends.
-- ==========================================
CREATE TABLE distribution_lists (
    id                  UUID        PRIMARY KEY,
    name                VARCHAR(255) NOT NULL,
    description         TEXT,
    external_key        VARCHAR(255) UNIQUE,    -- SFMC DataExtensionKey; populated after provider creation
    subscriber_count    INTEGER     NOT NULL DEFAULT 0 CHECK (subscriber_count >= 0),
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_distlist_external_key ON distribution_lists(external_key) WHERE external_key IS NOT NULL;

-- Enforce the FK from notification_audits now that distribution_lists exists
ALTER TABLE notification_audits
    ADD CONSTRAINT fk_audit_list
    FOREIGN KEY (list_id) REFERENCES distribution_lists(id) ON DELETE SET NULL;

-- ==========================================
-- DOMAIN: USER NOTIFICATIONS
-- In-app alert / notification records
-- registered against individual users.
-- ==========================================
CREATE TABLE user_notifications (
    notification_id     UUID        PRIMARY KEY,
    user_id             VARCHAR(100) NOT NULL,
    message             TEXT        NOT NULL,
    metadata            JSONB,                  -- Arbitrary key-value context for the notification
    active_start_date   TIMESTAMP WITH TIME ZONE,
    active_end_date     TIMESTAMP WITH TIME ZONE,
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_active_dates CHECK (
        active_end_date IS NULL OR active_start_date IS NULL OR active_end_date > active_start_date
    )
);

CREATE INDEX idx_user_notif_user_id    ON user_notifications(user_id);
CREATE INDEX idx_user_notif_active     ON user_notifications(user_id, active_start_date, active_end_date)
    WHERE active_end_date IS NULL OR active_end_date > CURRENT_TIMESTAMP;
CREATE INDEX idx_user_notif_metadata   ON user_notifications USING GIN (metadata);
