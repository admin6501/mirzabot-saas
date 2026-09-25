-- Mirza SaaS foundation, schema version 1.
-- Apply only after a consistent database AND vpnbot/data backup.
-- This migration is intentionally not invoked by db/bootstrap.php.
-- It does not enable tenant access or alter existing application queries.
-- MySQL 8.0 / InnoDB; execute with a dedicated migration account.

CREATE TABLE IF NOT EXISTS saas_schema_versions (
    version INT UNSIGNED NOT NULL PRIMARY KEY,
    applied_at DATETIME(6) NOT NULL,
    checksum CHAR(64) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tenants (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    public_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    slug VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    status ENUM('active','suspended','deleted') NOT NULL DEFAULT 'active',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at DATETIME(6) NULL,
    UNIQUE KEY uq_tenants_public_id (public_id),
    UNIQUE KEY uq_tenants_slug (slug),
    KEY idx_tenants_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS saas_accounts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(254) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    status ENUM('active','suspended','deleted') NOT NULL DEFAULT 'active',
    last_login_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    UNIQUE KEY uq_saas_accounts_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tenant_memberships (
    tenant_id BIGINT UNSIGNED NOT NULL,
    account_id BIGINT UNSIGNED NOT NULL,
    role ENUM('TENANT_OWNER','TENANT_ADMIN','TENANT_STAFF') NOT NULL,
    status ENUM('active','suspended') NOT NULL DEFAULT 'active',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (tenant_id, account_id),
    KEY idx_memberships_account (account_id, status),
    CONSTRAINT fk_membership_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT,
    CONSTRAINT fk_membership_account FOREIGN KEY (account_id) REFERENCES saas_accounts(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS saas_super_admins (
    account_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    granted_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_super_admin_account FOREIGN KEY (account_id) REFERENCES saas_accounts(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tenant_bots (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    public_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    tenant_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(255) NOT NULL,
    telegram_bot_id BIGINT UNSIGNED NOT NULL,
    username VARCHAR(64) NOT NULL,
    token_ciphertext VARBINARY(1024) NOT NULL,
    token_nonce VARBINARY(24) NOT NULL,
    token_key_version SMALLINT UNSIGNED NOT NULL,
    token_fingerprint BINARY(32) NOT NULL,
    webhook_secret_hash BINARY(32) NULL,
    status ENUM('PROVISIONING','ACTIVE','PAUSED','SUSPENDED','ERROR','DELETING','DELETED') NOT NULL DEFAULT 'PROVISIONING',
    last_activity_at DATETIME(6) NULL,
    last_error_code VARCHAR(100) NULL,
    deleted_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    UNIQUE KEY uq_bots_public_id (public_id),
    UNIQUE KEY uq_bots_telegram_id (telegram_bot_id),
    UNIQUE KEY uq_bots_token_fingerprint (token_fingerprint),
    UNIQUE KEY uq_bots_tenant_id (tenant_id, id),
    KEY idx_bots_tenant_status (tenant_id, status),
    CONSTRAINT fk_bot_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS saas_plans (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(64) NOT NULL,
    name VARCHAR(128) NOT NULL,
    max_bots INT UNSIGNED NOT NULL,
    max_customers INT UNSIGNED NULL,
    max_panels INT UNSIGNED NULL,
    storage_bytes BIGINT UNSIGNED NULL,
    max_backups INT UNSIGNED NULL,
    feature_permissions JSON NOT NULL,
    grace_days INT UNSIGNED NOT NULL DEFAULT 3,
    active TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY uq_plans_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tenant_subscriptions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    tenant_id BIGINT UNSIGNED NOT NULL,
    plan_id BIGINT UNSIGNED NOT NULL,
    starts_at DATETIME(6) NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    grace_days_override INT UNSIGNED NULL,
    status ENUM('active','expired','suspended','cancelled') NOT NULL DEFAULT 'active',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    KEY idx_subscriptions_tenant_expiry (tenant_id, expires_at),
    KEY idx_subscriptions_status_expiry (status, expires_at),
    CONSTRAINT fk_subscription_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT,
    CONSTRAINT fk_subscription_plan FOREIGN KEY (plan_id) REFERENCES saas_plans(id) ON DELETE RESTRICT,
    CONSTRAINT ck_subscription_dates CHECK (expires_at > starts_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tenant_domains (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    tenant_id BIGINT UNSIGNED NOT NULL,
    domain VARCHAR(253) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    status ENUM('pending','verified','disabled') NOT NULL DEFAULT 'pending',
    ssl_status ENUM('pending','active','error') NOT NULL DEFAULT 'pending',
    verified_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    UNIQUE KEY uq_tenant_domains_domain (domain),
    KEY idx_domains_tenant (tenant_id),
    CONSTRAINT fk_domain_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
