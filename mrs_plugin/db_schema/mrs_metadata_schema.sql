-- -----------------------------------------------------
-- MySQL REST Service Metadata Schema - CREATE Script

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- -----------------------------------------------------
-- Schema mysql_rest_service_metadata
--
-- Holds metadata information for the MySQL REST Service.
-- -----------------------------------------------------
DROP SCHEMA IF EXISTS `mysql_rest_service_metadata`;
CREATE SCHEMA `mysql_rest_service_metadata` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
USE `mysql_rest_service_metadata`;

-- Set schema_version to 0.0.0 to indicate an ongoing creation/upgrade of the schema
CREATE SQL SECURITY INVOKER VIEW `mysql_rest_service_metadata`.`schema_version` (major, minor, patch) AS SELECT 0, 0, 0;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`url_host`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`url_host` (
  `id` BINARY(16) NOT NULL,
  `name` VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'Specifies the host name of the MRS as represented in the request URLs. Example: example.com',
  `comments` VARCHAR(512) NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `name_UNIQUE` (`name` ASC) VISIBLE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`service`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`service` (
  `id` BINARY(16) NOT NULL,
  `parent_id` BINARY(16) NULL,
  `url_host_id` BINARY(16) NOT NULL,
  `url_context_root` VARCHAR(255) NOT NULL DEFAULT '/mrs' COMMENT 'Specifies context root of the MRS as represented in the request URLs, default being /mrs. URL Example: https://www.example.com/mrs',
  `url_protocol` SET('HTTP', 'HTTPS') NOT NULL DEFAULT 'HTTP,HTTPS',
  `name` VARCHAR(255) NOT NULL,
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `published` TINYINT NOT NULL DEFAULT 0,
  `in_development` JSON NULL COMMENT 'If not NULL, this column indicates that the REST service is currently \"in development\" and holds the name(s) of the developer(s) who is(/are) allowed to work with the service in the \"$.developers\" string array. REST services with this column not being NULL may use the same url_host+url_context_root context path as existing services. Routers only serve REST services with this column being NULL, unless they are bootstrapped with --mrs-development <user> which sets `router`.`option`->>\"$.developer\". When bootstrapped with the --mrs-development <user> option the Router also serves REST services marked \"in development\" with this column\'s \"$.developers\" including the same name as the <user> specified during bootstrap, while these REST services marked \"in development\" take priority over services with the same url_host+url_context_root context path and this column being NULL.',
  `comments` VARCHAR(512) NULL,
  `options` JSON NULL,
  `auth_path` VARCHAR(255) NOT NULL DEFAULT '/authentication' COMMENT 'The path used for authentication. The following sub-paths will be made available for <service_path>/<auth_path>:  /login /status /logout /completed',
  `auth_completed_url` VARCHAR(255) NULL COMMENT 'The authentication workflow will redirect to this URL after successful- or failed login. If this field is not set, the workflow will redirect to <service_path>/<auth_path>/completed if the <service_path>/<auth_path>/login?onCompletionRedirect parameter has not been set.',
  `auth_completed_url_validation` VARCHAR(512) NULL COMMENT 'A regular expression to validate the <service_path>/<auth_path>/login?onCompletionRedirect parameter. If set, this allows to limit the possible URLs an application can specify for this parameter.',
  `auth_completed_page_content` TEXT NULL COMMENT 'If this field is set its content will replace the page content of the /completed page.',
  `enable_sql_endpoint` TINYINT NOT NULL DEFAULT 0,
  `custom_metadata_schema` VARCHAR(255) NULL,
  `metadata` JSON NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_service_url_host1_idx` (`url_host_id` ASC) VISIBLE,
  INDEX `fk_service_service1_idx` (`parent_id` ASC) VISIBLE,
  CONSTRAINT `fk_service_url_host1`
    FOREIGN KEY (`url_host_id`)
    REFERENCES `mysql_rest_service_metadata`.`url_host` (`id`)
    ON DELETE RESTRICT
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_service_service1`
    FOREIGN KEY (`parent_id`)
    REFERENCES `mysql_rest_service_metadata`.`service` (`id`)
    ON DELETE RESTRICT
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`db_schema`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`db_schema` (
  `id` BINARY(16) NOT NULL,
  `service_id` BINARY(16) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `schema_type` ENUM('DATABASE_SCHEMA', 'SCRIPT_MODULE') NOT NULL DEFAULT 'DATABASE_SCHEMA',
  `request_path` VARCHAR(255) NOT NULL,
  `requires_auth` TINYINT NOT NULL DEFAULT 0,
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `internal` TINYINT NOT NULL DEFAULT 0,
  `items_per_page` INT UNSIGNED NULL DEFAULT 25,
  `comments` VARCHAR(512) NULL,
  `options` JSON NULL,
  `metadata` JSON NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_db_schema_service1_idx` (`service_id` ASC) VISIBLE,
  CONSTRAINT `fk_db_schema_service1`
    FOREIGN KEY (`service_id`)
    REFERENCES `mysql_rest_service_metadata`.`service` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`db_object`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`db_object` (
  `id` BINARY(16) NOT NULL,
  `db_schema_id` BINARY(16) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `request_path` VARCHAR(255) NOT NULL,
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `internal` TINYINT NOT NULL DEFAULT 0,
  `object_type` ENUM('TABLE', 'VIEW', 'PROCEDURE', 'FUNCTION', 'SCRIPT') NOT NULL,
  `crud_operations` SET('CREATE', 'READ', 'UPDATE', 'DELETE') NOT NULL DEFAULT '' COMMENT 'Calculated by the duality view options of object and object_reference table, always UPDATE for procedures and functions.',
  `format` ENUM('FEED', 'ITEM', 'MEDIA') NOT NULL DEFAULT 'FEED' COMMENT 'The HTTP request method for this handler. \'feed\' executes the source query and returns the result set in JSON representation, \'item\' returns a single row instead, \'media\' turns the result set into a binary representation with accompanying HTTP Content-Type header.',
  `items_per_page` INT UNSIGNED NULL,
  `media_type` VARCHAR(45) NULL,
  `auto_detect_media_type` TINYINT NOT NULL DEFAULT 0,
  `requires_auth` TINYINT NOT NULL DEFAULT 0,
  `auth_stored_procedure` VARCHAR(255) NULL DEFAULT 0 COMMENT 'Specifies the STORE PROCEDURE that should be called to identify if the given user is allowed to perform the given CRUD operation. The SP has to be in the same schema as the schema object and it has to accept the following parameters: (user_id, schema, object, crud_operation).  It returns true or false.',
  `options` JSON NULL COMMENT 'Holds additional options for the db_object, e.g. {\"id_generation\": \"auto_increment\"}. \"id_generation\" can be undefined or \"auto_increment\" for tables using AUTO_INCREMENT or \"reverse_uuid\" for tables using DECIMAL(16) for the primary key.',
  `details` JSON NULL,
  `comments` VARCHAR(512) NULL,
  `metadata` JSON NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_db_objects_db_schema1_idx` (`db_schema_id` ASC) INVISIBLE,
  CONSTRAINT `fk_db_objects_db_schema1`
    FOREIGN KEY (`db_schema_id`)
    REFERENCES `mysql_rest_service_metadata`.`db_schema` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`auth_vendor`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`auth_vendor` (
  `id` BINARY(16) NOT NULL,
  `name` VARCHAR(65) NOT NULL,
  `validation_url` VARCHAR(255) NULL COMMENT 'URL used to validate the access_token provided by the client. Example: https://graph.facebook.com/debug_token?input_token=%access_token%&access_token=%app_access_token%',
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `comments` VARCHAR(512) NULL,
  `options` JSON NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`auth_app`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`auth_app` (
  `id` BINARY(16) NOT NULL,
  `auth_vendor_id` BINARY(16) NOT NULL,
  `name` VARCHAR(45) NULL,
  `description` VARCHAR(512) NULL,
  `url` VARCHAR(255) NULL,
  `url_direct_auth` VARCHAR(255) NULL,
  `access_token` VARCHAR(1024) NULL COMMENT 'The app access token to validate the user login.',
  `app_id` VARCHAR(1024) NULL,
  `enabled` TINYINT NULL,
  `limit_to_registered_users` TINYINT NOT NULL DEFAULT 1 COMMENT 'Limit the users that can log in to the list of users in the auth_user table. The auth_user table can be pre-filled with users by specifying the name and email only. The vendor_user_id will be added on the first login automatically.',
  `default_role_id` BINARY(16) NULL COMMENT 'If set, a new user that has not any auth_roles assigned will get this role assigned when he logs in the first time.',
  `options` JSON NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_auth_app_auth_vendor1_idx` (`auth_vendor_id` ASC) VISIBLE,
  CONSTRAINT `fk_auth_app_auth_vendor1`
    FOREIGN KEY (`auth_vendor_id`)
    REFERENCES `mysql_rest_service_metadata`.`auth_vendor` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`mrs_user`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`mrs_user` (
  `id` BINARY(16) NOT NULL,
  `auth_app_id` BINARY(16) NOT NULL,
  `name` VARCHAR(225) NULL,
  `email` VARCHAR(255) NULL,
  `vendor_user_id` VARCHAR(255) NULL,
  `login_permitted` TINYINT NOT NULL DEFAULT 0,
  `mapped_user_id` VARCHAR(255) NULL,
  `app_options` JSON NULL,
  `auth_string` TEXT NULL,
  `options` JSON NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_auth_user_auth_app1_idx` (`auth_app_id` ASC) VISIBLE,
  CONSTRAINT `fk_auth_user_auth_app1`
    FOREIGN KEY (`auth_app_id`)
    REFERENCES `mysql_rest_service_metadata`.`auth_app` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`config`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`config` (
  `id` TINYINT NOT NULL DEFAULT 1,
  `service_enabled` TINYINT NULL,
  `data` JSON NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`redirect`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`redirect` (
  `id` BINARY(16) NOT NULL,
  `pattern` VARCHAR(1024) NULL,
  `target` VARCHAR(512) NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`url_host_alias`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`url_host_alias` (
  `id` BINARY(16) NOT NULL,
  `url_host_id` BINARY(16) NOT NULL,
  `alias` VARCHAR(255) NOT NULL COMMENT 'Specifies additional aliases for the given host, e.g. www.example.com',
  PRIMARY KEY (`id`),
  INDEX `fk_url_host_alias_url_host1_idx` (`url_host_id` ASC) VISIBLE,
  CONSTRAINT `fk_url_host_alias_url_host1`
    FOREIGN KEY (`url_host_id`)
    REFERENCES `mysql_rest_service_metadata`.`url_host` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`content_set`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`content_set` (
  `id` BINARY(16) NOT NULL,
  `service_id` BINARY(16) NOT NULL,
  `content_type` ENUM('STATIC', 'SCRIPTS') NOT NULL DEFAULT 'STATIC',
  `request_path` VARCHAR(255) NOT NULL,
  `requires_auth` TINYINT NOT NULL DEFAULT 0,
  `enabled` TINYINT NOT NULL DEFAULT 0,
  `internal` TINYINT NOT NULL DEFAULT 0,
  `comments` VARCHAR(512) NULL,
  `options` JSON NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_static_content_version_service1_idx` (`service_id` ASC) VISIBLE,
  CONSTRAINT `fk_static_content_version_service1`
    FOREIGN KEY (`service_id`)
    REFERENCES `mysql_rest_service_metadata`.`service` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`content_file`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`content_file` (
  `id` BINARY(16) NOT NULL,
  `content_set_id` BINARY(16) NOT NULL,
  `request_path` VARCHAR(255) NOT NULL DEFAULT '/',
  `requires_auth` TINYINT NOT NULL DEFAULT 0,
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `content` LONGBLOB NOT NULL,
  `size` BIGINT GENERATED ALWAYS AS (LENGTH(content)) STORED,
  `options` JSON NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_content_content_set1_idx` (`content_set_id` ASC) VISIBLE,
  CONSTRAINT `fk_content_content_set1`
    FOREIGN KEY (`content_set_id`)
    REFERENCES `mysql_rest_service_metadata`.`content_set` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`audit_log`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`audit_log` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `schema_name` VARCHAR(255) NULL,
  `table_name` VARCHAR(255) NOT NULL,
  `dml_type` ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  `old_row_data` JSON NULL,
  `new_row_data` JSON NULL,
  `changed_by` VARCHAR(255) NOT NULL,
  `changed_at` TIMESTAMP NOT NULL,
  `old_row_id` BINARY(16) NULL,
  `new_row_id` BINARY(16) NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_table_name` (`table_name` ASC) VISIBLE,
  INDEX `idx_changed_at` (`changed_at` ASC) VISIBLE,
  INDEX `idx_changed_by` (`changed_by` ASC) VISIBLE,
  INDEX `idx_new_row_id` (`new_row_id` ASC) VISIBLE,
  INDEX `idx_old_row_id` (`old_row_id` ASC) VISIBLE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`mrs_role`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`mrs_role` (
  `id` BINARY(16) NOT NULL,
  `derived_from_role_id` BINARY(16) NULL,
  `specific_to_service_id` BINARY(16) NULL,
  `caption` VARCHAR(150) NOT NULL,
  `description` VARCHAR(512) NULL,
  `options` JSON NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_priv_role_priv_role1_idx` (`derived_from_role_id` ASC) VISIBLE,
  INDEX `fk_auth_role_service1_idx` (`specific_to_service_id` ASC) VISIBLE,
  UNIQUE INDEX `auth_role_unique_caption` (`caption` ASC) VISIBLE,
  CONSTRAINT `fk_priv_role_priv_role1`
    FOREIGN KEY (`derived_from_role_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_role` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_auth_role_service1`
    FOREIGN KEY (`specific_to_service_id`)
    REFERENCES `mysql_rest_service_metadata`.`service` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`mrs_user_has_role`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`mrs_user_has_role` (
  `user_id` BINARY(16) NOT NULL,
  `role_id` BINARY(16) NOT NULL,
  `comments` VARCHAR(512) NULL,
  `options` JSON NULL,
  PRIMARY KEY (`user_id`, `role_id`),
  INDEX `fk_auth_user_has_privilege_role_privilege_role1_idx` (`role_id` ASC) VISIBLE,
  INDEX `fk_auth_user_has_privilege_role_auth_user1_idx` (`user_id` ASC) VISIBLE,
  CONSTRAINT `fk_auth_user_has_privilege_role_auth_user1`
    FOREIGN KEY (`user_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_user` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_auth_user_has_privilege_role_privilege_role1`
    FOREIGN KEY (`role_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_role` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`mrs_user_hierarchy_type`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`mrs_user_hierarchy_type` (
  `id` BINARY(16) NOT NULL,
  `caption` VARCHAR(150) NULL,
  `description` VARCHAR(512) NULL,
  `specific_to_service_id` BINARY(16) NULL,
  `options` JSON NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_user_hierarchy_type_service1_idx` (`specific_to_service_id` ASC) VISIBLE,
  CONSTRAINT `fk_user_hierarchy_type_service1`
    FOREIGN KEY (`specific_to_service_id`)
    REFERENCES `mysql_rest_service_metadata`.`service` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`mrs_user_hierarchy`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`mrs_user_hierarchy` (
  `user_id` BINARY(16) NOT NULL,
  `reporting_to_user_id` BINARY(16) NOT NULL,
  `user_hierarchy_type_id` BINARY(16) NOT NULL,
  `options` JSON NULL,
  PRIMARY KEY (`user_id`, `reporting_to_user_id`, `user_hierarchy_type_id`),
  INDEX `fk_user_hierarchy_auth_user2_idx` (`reporting_to_user_id` ASC) VISIBLE,
  INDEX `fk_user_hierarchy_hierarchy_type1_idx` (`user_hierarchy_type_id` ASC) VISIBLE,
  CONSTRAINT `fk_user_hierarchy_auth_user1`
    FOREIGN KEY (`user_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_user` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_user_hierarchy_auth_user2`
    FOREIGN KEY (`reporting_to_user_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_user` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_user_hierarchy_hierarchy_type1`
    FOREIGN KEY (`user_hierarchy_type_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_user_hierarchy_type` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`mrs_privilege`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`mrs_privilege` (
  `id` BINARY(16) NOT NULL,
  `role_id` BINARY(16) NOT NULL,
  `crud_operations` SET('CREATE', 'READ', 'UPDATE', 'DELETE') NOT NULL DEFAULT '',
  `service_id` BINARY(16) NULL,
  `db_schema_id` BINARY(16) NULL,
  `db_object_id` BINARY(16) NULL,
  `options` JSON NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_priv_on_schema_db_schema1_idx` (`db_schema_id` ASC) VISIBLE,
  INDEX `fk_priv_on_schema_service1_idx` (`service_id` ASC) VISIBLE,
  INDEX `fk_priv_on_schema_db_object1_idx` (`db_object_id` ASC) VISIBLE,
  CONSTRAINT `fk_priv_on_schema_auth_role1`
    FOREIGN KEY (`role_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_role` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_priv_on_schema_db_schema1`
    FOREIGN KEY (`db_schema_id`)
    REFERENCES `mysql_rest_service_metadata`.`db_schema` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_priv_on_schema_service1`
    FOREIGN KEY (`service_id`)
    REFERENCES `mysql_rest_service_metadata`.`service` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_priv_on_schema_db_object1`
    FOREIGN KEY (`db_object_id`)
    REFERENCES `mysql_rest_service_metadata`.`db_object` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`mrs_user_group`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`mrs_user_group` (
  `id` BINARY(16) NOT NULL,
  `specific_to_service_id` BINARY(16) NULL,
  `caption` VARCHAR(45) NULL,
  `description` VARCHAR(512) NULL,
  `options` JSON NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_user_group_service1_idx` (`specific_to_service_id` ASC) VISIBLE,
  CONSTRAINT `fk_user_group_service1`
    FOREIGN KEY (`specific_to_service_id`)
    REFERENCES `mysql_rest_service_metadata`.`service` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`mrs_user_group_has_role`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`mrs_user_group_has_role` (
  `user_group_id` BINARY(16) NOT NULL,
  `role_id` BINARY(16) NOT NULL,
  `options` JSON NULL,
  PRIMARY KEY (`user_group_id`, `role_id`),
  INDEX `fk_user_group_has_auth_role_auth_role1_idx` (`role_id` ASC) VISIBLE,
  INDEX `fk_user_group_has_auth_role_user_group1_idx` (`user_group_id` ASC) VISIBLE,
  CONSTRAINT `fk_user_group_has_auth_role_user_group1`
    FOREIGN KEY (`user_group_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_user_group` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_user_group_has_auth_role_auth_role1`
    FOREIGN KEY (`role_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_role` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`mrs_user_has_group`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`mrs_user_has_group` (
  `user_id` BINARY(16) NOT NULL,
  `user_group_id` BINARY(16) NOT NULL,
  `comments` VARCHAR(512) NULL,
  `options` JSON NULL,
  PRIMARY KEY (`user_id`, `user_group_id`),
  INDEX `fk_auth_user_has_user_group_user_group1_idx` (`user_group_id` ASC) VISIBLE,
  INDEX `fk_auth_user_has_user_group_auth_user1_idx` (`user_id` ASC) VISIBLE,
  CONSTRAINT `fk_auth_user_has_user_group_auth_user1`
    FOREIGN KEY (`user_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_user` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_auth_user_has_user_group_user_group1`
    FOREIGN KEY (`user_group_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_user_group` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`mrs_group_hierarchy_type`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`mrs_group_hierarchy_type` (
  `id` BINARY(16) NOT NULL,
  `caption` VARCHAR(150) NULL,
  `description` VARCHAR(512) NULL,
  `options` JSON NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`mrs_user_group_hierarchy`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`mrs_user_group_hierarchy` (
  `user_group_id` BINARY(16) NOT NULL,
  `parent_group_id` BINARY(16) NOT NULL,
  `group_hierarchy_type_id` BINARY(16) NOT NULL,
  `level` INT UNSIGNED NOT NULL DEFAULT 0,
  `options` JSON NULL,
  PRIMARY KEY (`user_group_id`, `parent_group_id`, `group_hierarchy_type_id`),
  INDEX `fk_user_group_has_user_group_user_group2_idx` (`parent_group_id` ASC) VISIBLE,
  INDEX `fk_user_group_has_user_group_user_group1_idx` (`user_group_id` ASC) VISIBLE,
  INDEX `fk_user_group_hierarchy_group_hierarchy_type1_idx` (`group_hierarchy_type_id` ASC) VISIBLE,
  CONSTRAINT `fk_user_group_has_user_group_user_group1`
    FOREIGN KEY (`user_group_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_user_group` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_user_group_has_user_group_user_group2`
    FOREIGN KEY (`parent_group_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_user_group` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_user_group_hierarchy_group_hierarchy_type1`
    FOREIGN KEY (`group_hierarchy_type_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_group_hierarchy_type` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`mrs_db_object_row_group_security`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`mrs_db_object_row_group_security` (
  `db_object_id` BINARY(16) NOT NULL,
  `group_hierarchy_type_id` BINARY(16) NOT NULL,
  `row_group_ownership_column` VARCHAR(255) NOT NULL,
  `level` INT UNSIGNED NOT NULL DEFAULT 0,
  `match_level` ENUM('HIGHER', 'EQUAL OR HIGHER', 'EQUAL', 'LOWER OR EQUAL', 'LOWER') NOT NULL DEFAULT 'HIGHER',
  `options` JSON NULL,
  INDEX `fk_table1_db_object1_idx` (`db_object_id` ASC) VISIBLE,
  INDEX `fk_db_object_row_security_group_hierarchy_type1_idx` (`group_hierarchy_type_id` ASC) VISIBLE,
  PRIMARY KEY (`db_object_id`, `group_hierarchy_type_id`),
  CONSTRAINT `fk_table1_db_object1`
    FOREIGN KEY (`db_object_id`)
    REFERENCES `mysql_rest_service_metadata`.`db_object` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_db_object_row_security_group_hierarchy_type1`
    FOREIGN KEY (`group_hierarchy_type_id`)
    REFERENCES `mysql_rest_service_metadata`.`mrs_group_hierarchy_type` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`router`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`router` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'The ID of the router instance that uniquely identifies the router on this MySQL REST Service setup.',
  `router_name` VARCHAR(255) NOT NULL COMMENT 'A user specified name for an instance of the router. Should default to address:port, where port is the RW port for classic protocol. Set via --name during router bootstrap.',
  `address` VARCHAR(255) CHARACTER SET 'ascii' COLLATE 'ascii_general_ci' NOT NULL COMMENT 'Network address of the host the Router is running on. Set via --report--host during bootstrap.',
  `product_name` VARCHAR(128) NOT NULL COMMENT 'The product name of the routing component, e.g. \'MySQL Router\'',
  `version` VARCHAR(12) NULL COMMENT 'The version of the router instance. Updated on bootstrap and each startup of the router instance. Format: x.y.z, 3 digits for each component. Managed by Router.',
  `last_check_in` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'A timestamp updated by the router every hour with the current time. This timestamp is used to detect routers that are no longer used or stalled. Managed by Router.',
  `attributes` JSON NULL COMMENT 'Router specific custom attributes. Managed by Router.',
  `options` JSON NULL COMMENT 'Router instance specific configuration options.',
  PRIMARY KEY (`id`),
  UNIQUE INDEX `address_router_name` (`address` ASC, `router_name` ASC) VISIBLE)
ENGINE = InnoDB
COMMENT = 'no_audit_log';


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`router_status`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`router_status` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `router_id` INT UNSIGNED NOT NULL,
  `status_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'The time the status was reported',
  `timespan` SMALLINT NOT NULL COMMENT 'The timespan of the measuring interval',
  `mysql_connections` MEDIUMINT NOT NULL DEFAULT 0,
  `mysql_queries` MEDIUMINT NOT NULL DEFAULT 0,
  `http_requests_get` MEDIUMINT NOT NULL DEFAULT 0,
  `http_requests_post` MEDIUMINT NOT NULL DEFAULT 0,
  `http_requests_put` MEDIUMINT NOT NULL DEFAULT 0,
  `http_requests_delete` MEDIUMINT NOT NULL DEFAULT 0,
  `active_mysql_connections` MEDIUMINT NOT NULL DEFAULT 0,
  `details` JSON NULL COMMENT 'More detailed status information',
  PRIMARY KEY (`id`),
  INDEX `fk_router_status_router1_idx` (`router_id` ASC) VISIBLE,
  INDEX `status_time` (`status_time` ASC) VISIBLE,
  CONSTRAINT `fk_router_status_router1`
    FOREIGN KEY (`router_id`)
    REFERENCES `mysql_rest_service_metadata`.`router` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
COMMENT = 'no_audit_log';


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`router_session`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`router_session` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BINARY(16) NOT NULL,
  `service_id` BINARY(16) NOT NULL,
  `expires` DATETIME NOT NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
COMMENT = 'no_audit_log';


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`router_general_log`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`router_general_log` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `router_id` INT UNSIGNED NOT NULL,
  `router_session_id` INT UNSIGNED NULL,
  `log_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `log_type` ENUM("INFO", "WARNING", "ERROR") NOT NULL,
  `code` SMALLINT UNSIGNED NULL,
  `message` VARCHAR(255) NULL,
  `data` JSON NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_router_general_log_router1_idx` (`router_id` ASC) VISIBLE,
  INDEX `log_time` (`log_time` ASC) VISIBLE,
  INDEX `fk_router_general_log_router_session1_idx` (`router_session_id` ASC) VISIBLE,
  CONSTRAINT `fk_router_general_log_router1`
    FOREIGN KEY (`router_id`)
    REFERENCES `mysql_rest_service_metadata`.`router` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_router_general_log_router_session1`
    FOREIGN KEY (`router_session_id`)
    REFERENCES `mysql_rest_service_metadata`.`router_session` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
COMMENT = 'no_audit_log';


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`object`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`object` (
  `id` BINARY(16) NOT NULL,
  `db_object_id` BINARY(16) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `kind` ENUM("RESULT", "PARAMETERS") NOT NULL DEFAULT 'RESULT',
  `position` INT NOT NULL DEFAULT 0,
  `row_ownership_field_id` BINARY(16) NULL,
  `options` JSON NULL COMMENT 'Holds duality view options for INSERT, UPDATE, DELETE and CHECK, e.g. { duality_view_insert: true, duality_view_update: true, duality_view_delete: false, duality_view_no_check: false }',
  `sdk_options` JSON NULL,
  `comments` VARCHAR(512) NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_result_db_object1_idx` (`db_object_id` ASC) VISIBLE,
  INDEX `row_ownership_object_idx` (`row_ownership_field_id` ASC) VISIBLE,
  CONSTRAINT `fk_result_db_object1`
    FOREIGN KEY (`db_object_id`)
    REFERENCES `mysql_rest_service_metadata`.`db_object` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`object_reference`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`object_reference` (
  `id` BINARY(16) NOT NULL,
  `reduce_to_value_of_field_id` BINARY(16) NULL COMMENT 'If set to an object_field, this reference will be reduced to the value of the given field. Example: \"films\": [ { \"categories\": [ \"Thriller\", \"Action\"] } ] instead of \"films\": [ { \"categories\": [ { \"name\": \"Thriller\" }, { \"name\": \"Action\" } ] } ],',
  `row_ownership_field_id` BINARY(16) NULL,
  `reference_mapping` JSON NOT NULL COMMENT 'Holds all column mappings of the FK, {kind:\"n:1\", constraint: \"constraint_name\", referenced_schema: \"schema_name\", referenced_table: \"table_name\", column_mapping: [{\"column_name\": \"referenced_column_name\"}, \"to_many\": true, \"id_generation\": \"auto_increment\"}. \"id_generation\" can be undefined or \"auto_increment\" for tables using AUTO_INCREMENT or \"reverse_uuid\" for tables using BINARY(16) for the primary key.',
  `unnest` BIT(1) NOT NULL DEFAULT 0 COMMENT 'If set to TRUE, the properties will be directly added to the parent',
  `options` JSON NULL COMMENT 'Holds duality view options for INSERT, UPDATE, DELETE and CHECK, e.g. { duality_view_insert: true, duality_view_update: true, duality_view_delete: false, duality_view_no_check: false }',
  `sdk_options` JSON NULL,
  `comments` VARCHAR(512) NULL,
  PRIMARY KEY (`id`),
  INDEX `reduce_to_idx` (`reduce_to_value_of_field_id` ASC) VISIBLE,
  INDEX `row_ownership_object_reference_idx` (`row_ownership_field_id` ASC) VISIBLE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`object_field`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`object_field` (
  `id` BINARY(16) NOT NULL,
  `object_id` BINARY(16) NOT NULL,
  `parent_reference_id` BINARY(16) NULL,
  `represents_reference_id` BINARY(16) NULL,
  `name` VARCHAR(255) NOT NULL COMMENT 'The name of the field as returned in the JSON',
  `position` INT NOT NULL,
  `db_column` JSON NULL COMMENT 'Holds information about the original database column, e.g. {\"name\": \"first_name\", \"datatype\":\"VARCHAR(45)\", \"not_null\": true, \"is_primary\": false, \"is_unique\": false, \"is_generated\": false, \"auto_inc\": false}. When representing a STORED PROCEDURE parameter, two optional fields can be set, {\"in\": true, \"out\": false}',
  `enabled` BIT(1) NOT NULL DEFAULT 1 COMMENT 'When set to FALSE, the property is hidden from the result',
  `allow_filtering` BIT(1) NOT NULL DEFAULT 1 COMMENT 'When set to FALSE the property is not available for filtering',
  `allow_sorting` BIT(1) NOT NULL DEFAULT 0 COMMENT 'When set to TRUE the field can be used for ordering',
  `no_check` BIT(1) NOT NULL DEFAULT 0 COMMENT 'Specifies whether the field should be ignored in the scope of concurrency control',
  `no_update` BIT(1) NOT NULL DEFAULT 0 COMMENT 'If set to 1 then no updates of this field are allowed.',
  `options` JSON NULL,
  `sdk_options` JSON NULL,
  `comments` VARCHAR(512) NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_properties_result1_idx` (`object_id` ASC) VISIBLE,
  INDEX `fk_result_property_result_reference1_idx` (`parent_reference_id` ASC) VISIBLE,
  INDEX `fk_result_property_result_reference2_idx` (`represents_reference_id` ASC) VISIBLE,
  CONSTRAINT `fk_properties_result1`
    FOREIGN KEY (`object_id`)
    REFERENCES `mysql_rest_service_metadata`.`object` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_result_property_result_reference1`
    FOREIGN KEY (`parent_reference_id`)
    REFERENCES `mysql_rest_service_metadata`.`object_reference` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_result_property_result_reference2`
    FOREIGN KEY (`represents_reference_id`)
    REFERENCES `mysql_rest_service_metadata`.`object_reference` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`service_has_auth_app`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`service_has_auth_app` (
  `service_id` BINARY(16) NOT NULL,
  `auth_app_id` BINARY(16) NOT NULL,
  `options` JSON NULL,
  PRIMARY KEY (`service_id`, `auth_app_id`),
  INDEX `fk_service_has_auth_app_auth_app1_idx` (`auth_app_id` ASC) VISIBLE,
  INDEX `fk_service_has_auth_app_service1_idx` (`service_id` ASC) VISIBLE,
  CONSTRAINT `fk_service_has_auth_app_service1`
    FOREIGN KEY (`service_id`)
    REFERENCES `mysql_rest_service_metadata`.`service` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_service_has_auth_app_auth_app1`
    FOREIGN KEY (`auth_app_id`)
    REFERENCES `mysql_rest_service_metadata`.`auth_app` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mysql_rest_service_metadata`.`content_set_has_obj_def`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mysql_rest_service_metadata`.`content_set_has_obj_def` (
  `content_set_id` BINARY(16) NOT NULL,
  `db_object_id` BINARY(16) NOT NULL,
  `method_type` ENUM("Script", "BeforeCreate", "BeforeRead", "BeforeUpdate", "BeforeDelete", "AfterCreate", "AfterRead", "AfterUpdate", "AfterDelete") NOT NULL,
  `priority` INT NOT NULL DEFAULT 0,
  `language` VARCHAR(45) NOT NULL,
  `class_name` VARCHAR(255) NOT NULL,
  `method_name` VARCHAR(255) NOT NULL,
  `comments` VARCHAR(512) NULL,
  `options` JSON NULL,
  INDEX `fk_content_set_has_obj_dev_db_object1_idx` (`db_object_id` ASC) VISIBLE,
  INDEX `fk_content_set_has_obj_dev_content_set1_idx` (`content_set_id` ASC) VISIBLE,
  INDEX `content_set_has_obj_dev_priority` (`priority` ASC) VISIBLE,
  PRIMARY KEY (`content_set_id`, `db_object_id`, `method_type`, `priority`),
  INDEX `content_set_has_obj_dev_method_type` (`method_type` ASC) VISIBLE,
  CONSTRAINT `fk_content_set_has_db_object_content_set1`
    FOREIGN KEY (`content_set_id`)
    REFERENCES `mysql_rest_service_metadata`.`content_set` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_content_set_has_db_object_db_object1`
    FOREIGN KEY (`db_object_id`)
    REFERENCES `mysql_rest_service_metadata`.`db_object` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

USE `mysql_rest_service_metadata` ;

-- -----------------------------------------------------
-- View `mysql_rest_service_metadata`.`mrs_user_schema_version`
-- -----------------------------------------------------
USE `mysql_rest_service_metadata`;
CREATE  OR REPLACE SQL SECURITY INVOKER VIEW mrs_user_schema_version (major, minor, patch) AS SELECT 3, 0, 0;

-- -----------------------------------------------------
-- View `mysql_rest_service_metadata`.`object_fields_with_references`
-- -----------------------------------------------------
USE `mysql_rest_service_metadata`;
CREATE  OR REPLACE SQL SECURITY INVOKER VIEW `object_fields_with_references` AS
WITH RECURSIVE obj_fields (
    caption, lev, position, id, represents_reference_id, parent_reference_id, object_id,
    name, db_column, enabled,
    allow_filtering, allow_sorting, no_check, no_update, options, sdk_options, comments,
    object_reference) AS
(
    SELECT CONCAT("- ", f.name) as caption, 1 AS lev, f.position, f.id,
		f.represents_reference_id, f.parent_reference_id, f.object_id, f.name,
        f.db_column, f.enabled, f.allow_filtering, f.allow_sorting, f.no_check, f.no_update,
        f.options, f.sdk_options, f.comments,
        IF(ISNULL(f.represents_reference_id), NULL, JSON_OBJECT(
            "reduce_to_value_of_field_id", TO_BASE64(r.reduce_to_value_of_field_id),
            "row_ownership_field_id", TO_BASE64(r.row_ownership_field_id),
            "reference_mapping", r.reference_mapping,
            "unnest", (r.unnest = 1),
            "options", r.options,
            "sdk_options", r.sdk_options,
            "comments", r.comments
        )) AS object_reference
    FROM `mysql_rest_service_metadata`.`object_field` f
        LEFT OUTER JOIN `mysql_rest_service_metadata`.`object_reference` AS r
            ON r.id = f.represents_reference_id
    WHERE ISNULL(parent_reference_id)
    UNION ALL
    SELECT CONCAT(REPEAT("  ", p.lev), "- ", f.name) as caption, p.lev+1 AS lev, f.position,
        f.id, f.represents_reference_id, f.parent_reference_id, f.object_id, f.name,
        f.db_column, f.enabled, f.allow_filtering, f.allow_sorting, f.no_check, f.no_update,
        f.options, f.sdk_options, f.comments,
        IF(ISNULL(f.represents_reference_id), NULL, JSON_OBJECT(
            "reduce_to_value_of_field_id", TO_BASE64(rc.reduce_to_value_of_field_id),
            "row_ownership_field_id", TO_BASE64(rc.row_ownership_field_id),
            "reference_mapping", rc.reference_mapping,
            "unnest", (rc.unnest = 1),
            "options", rc.options,
            "sdk_options", rc.sdk_options,
            "comments", rc.comments
        )) AS object_reference
    FROM obj_fields AS p JOIN `mysql_rest_service_metadata`.`object_reference` AS r
            ON r.id = p.represents_reference_id
        LEFT OUTER JOIN `mysql_rest_service_metadata`.`object_field` AS f
            ON r.id = f.parent_reference_id
        LEFT OUTER JOIN `mysql_rest_service_metadata`.`object_reference` AS rc
            ON rc.id = f.represents_reference_id
	WHERE f.id IS NOT NULL
)
SELECT * FROM obj_fields;

-- -----------------------------------------------------
-- View `mysql_rest_service_metadata`.`table_columns_with_references`
-- -----------------------------------------------------
USE `mysql_rest_service_metadata`;
CREATE  OR REPLACE SQL SECURITY INVOKER VIEW `table_columns_with_references` AS
SELECT f.* FROM (
	-- Get the table columns
	SELECT c.ORDINAL_POSITION AS position, c.COLUMN_NAME AS name,
        NULL AS ref_column_names,
        JSON_OBJECT(
            "name", c.COLUMN_NAME,
            "datatype", c.COLUMN_TYPE,
            "not_null", c.IS_NULLABLE = "NO",
            "is_primary", c.COLUMN_KEY = "PRI",
            "is_unique", c.COLUMN_KEY = "UNI",
            "is_generated", c.GENERATION_EXPRESSION <> "",
            "id_generation", IF(c.EXTRA = "auto_increment", "auto_inc",
                IF(c.COLUMN_KEY = "PRI" AND c.DATA_TYPE = "binary" AND c.CHARACTER_MAXIMUM_LENGTH = 16,
                    "rev_uuid", NULL)),
            "comment", c.COLUMN_COMMENT,
            "srid", c.SRS_ID,
            "column_default", c.COLUMN_DEFAULT
            ) AS db_column,
	    NULL AS reference_mapping,
        c.TABLE_SCHEMA as table_schema, c.TABLE_NAME as table_name
	FROM INFORMATION_SCHEMA.COLUMNS AS c
	    LEFT OUTER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS k
	        ON c.TABLE_SCHEMA = k.TABLE_SCHEMA AND c.TABLE_NAME = k.TABLE_NAME
                AND c.COLUMN_NAME=k.COLUMN_NAME
	            AND NOT ISNULL(k.POSITION_IN_UNIQUE_CONSTRAINT)
	-- Union with the references that point from the table to other tables (n:1)
	UNION
	SELECT MAX(c.ORDINAL_POSITION) + 100 AS position, MAX(k.REFERENCED_TABLE_NAME) AS name,
        GROUP_CONCAT(c.COLUMN_NAME SEPARATOR ', ') AS ref_column_names,
	    NULL AS db_column,
	    JSON_MERGE_PRESERVE(
			JSON_OBJECT("kind", "n:1"),
	        JSON_OBJECT("constraint",
                CONCAT(MAX(k.CONSTRAINT_SCHEMA), ".", MAX(k.CONSTRAINT_NAME))),
	        JSON_OBJECT("to_many", FALSE),
	        JSON_OBJECT("referenced_schema", MAX(k.REFERENCED_TABLE_SCHEMA)),
	        JSON_OBJECT("referenced_table", MAX(k.REFERENCED_TABLE_NAME)),
	        JSON_OBJECT("column_mapping",
                JSON_ARRAYAGG(JSON_OBJECT(
                    "base", c.COLUMN_NAME,
                    "ref", k.REFERENCED_COLUMN_NAME)))
	    ) AS reference_mapping,
        MAX(c.TABLE_SCHEMA) AS table_schema, MAX(c.TABLE_NAME) AS table_name
	FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS k
	    JOIN INFORMATION_SCHEMA.COLUMNS AS c
	        ON c.TABLE_SCHEMA = k.TABLE_SCHEMA AND c.TABLE_NAME = k.TABLE_NAME
                AND c.COLUMN_NAME=k.COLUMN_NAME
	WHERE NOT ISNULL(k.REFERENCED_TABLE_NAME)
    GROUP BY k.CONSTRAINT_NAME, k.table_schema, k.table_name
	UNION
	-- Union with the references that point from other tables to the table (1:1 and 1:n)
	SELECT MAX(c.ORDINAL_POSITION) + 1000 AS position,
        MAX(c.TABLE_NAME) AS name,
        GROUP_CONCAT(k.COLUMN_NAME SEPARATOR ', ') AS ref_column_names,
	    NULL AS db_column,
	    JSON_MERGE_PRESERVE(
	        -- If the PKs of the table and the referred table are exactly the same,
            -- this is a 1:1 relationship, otherwise an 1:n
			JSON_OBJECT("kind", IF(JSON_CONTAINS(MAX(PK_TABLE.PK), MAX(PK_REF.PK)) = 1,
				"1:1", "1:n")),
	        JSON_OBJECT("constraint",
                CONCAT(MAX(k.CONSTRAINT_SCHEMA), ".", MAX(k.CONSTRAINT_NAME))),
	        JSON_OBJECT("to_many", JSON_CONTAINS(MAX(PK_TABLE.PK), MAX(PK_REF.PK)) = 0),
	        JSON_OBJECT("referenced_schema", MAX(c.TABLE_SCHEMA)),
	        JSON_OBJECT("referenced_table", MAX(c.TABLE_NAME)),
	        JSON_OBJECT("column_mapping",
                JSON_ARRAYAGG(JSON_OBJECT(
                    "base", k.REFERENCED_COLUMN_NAME,
                    "ref", c.COLUMN_NAME)))
	    ) AS reference_mapping,
        MAX(k.REFERENCED_TABLE_SCHEMA) AS table_schema,
        MAX(k.REFERENCED_TABLE_NAME) AS table_name
	FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS k
	    JOIN INFORMATION_SCHEMA.COLUMNS AS c
	        ON c.TABLE_SCHEMA = k.TABLE_SCHEMA AND c.TABLE_NAME = k.TABLE_NAME
                AND c.COLUMN_NAME=k.COLUMN_NAME
	    -- The PK columns of the table, e.g. ["test_fk.product.id"]
	    JOIN (SELECT JSON_ARRAYAGG(CONCAT(c2.TABLE_SCHEMA, ".",
                    c2.TABLE_NAME, ".", c2.COLUMN_NAME)) AS PK,
	            c2.TABLE_SCHEMA, c2.TABLE_NAME
	            FROM INFORMATION_SCHEMA.COLUMNS AS c2
	            WHERE c2.COLUMN_KEY = "PRI"
	            GROUP BY c2.COLUMN_KEY, c2.TABLE_SCHEMA, c2.TABLE_NAME) AS PK_TABLE
	        ON PK_TABLE.TABLE_SCHEMA = k.REFERENCED_TABLE_SCHEMA
                AND PK_TABLE.TABLE_NAME = k.REFERENCED_TABLE_NAME
	    -- The PK columns of the referenced table,
        -- e.g. ["test_fk.product_part.id", "test_fk.product.id"]
	    JOIN (SELECT JSON_ARRAYAGG(PK2.PK_COL) AS PK, PK2.TABLE_SCHEMA, PK2.TABLE_NAME
	        FROM (SELECT IFNULL(
	            CONCAT(MAX(k1.REFERENCED_TABLE_SCHEMA), ".",
	                MAX(k1.REFERENCED_TABLE_NAME), ".", MAX(k1.REFERENCED_COLUMN_NAME)),
	            CONCAT(c1.TABLE_SCHEMA, ".", c1.TABLE_NAME, ".", c1.COLUMN_NAME)) AS PK_COL,
	            c1.TABLE_SCHEMA AS TABLE_SCHEMA, c1.TABLE_NAME AS TABLE_NAME
	            FROM INFORMATION_SCHEMA.COLUMNS AS c1
	                JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS k1
	                    ON k1.TABLE_SCHEMA = c1.TABLE_SCHEMA
                            AND k1.TABLE_NAME = c1.TABLE_NAME
	                        AND k1.COLUMN_NAME = c1.COLUMN_NAME
	            WHERE c1.COLUMN_KEY = "PRI"
	            GROUP BY c1.COLUMN_NAME, c1.TABLE_SCHEMA, c1.TABLE_NAME) AS PK2
	            GROUP BY PK2.TABLE_SCHEMA, PK2.TABLE_NAME) AS PK_REF
	        ON PK_REF.TABLE_SCHEMA = k.TABLE_SCHEMA AND PK_REF.TABLE_NAME = k.TABLE_NAME
	GROUP BY k.CONSTRAINT_NAME, c.TABLE_SCHEMA, c.TABLE_NAME
    ) AS f
ORDER BY f.position;

-- -----------------------------------------------------
-- View `mysql_rest_service_metadata`.`router_services`
-- -----------------------------------------------------
USE `mysql_rest_service_metadata`;
CREATE  OR REPLACE SQL SECURITY INVOKER VIEW `router_services` AS
SELECT r.id AS router_id, r.router_name, r.address, r.options->>'$.developer' AS router_developer,
    s.id as service_id, h.name AS service_url_host_name,
    s.url_context_root AS service_url_context_root,
    CONCAT(h.name, s.url_context_root) AS service_host_ctx,
    s.published, s.in_development,
    (SELECT GROUP_CONCAT(IF(item REGEXP '^[A-Za-z0-9_]+$', item, QUOTE(item)) ORDER BY item)
        FROM JSON_TABLE(
        s.in_development->>'$.developers', '$[*]' COLUMNS (item text path '$')
    ) AS jt) AS sorted_developers
FROM `mysql_rest_service_metadata`.`service` s
    LEFT JOIN `mysql_rest_service_metadata`.`url_host` h
        ON s.url_host_id = h.id
    JOIN `mysql_rest_service_metadata`.`router` r
WHERE
    (enabled = 1)
    AND (
    ((published = 1) AND (NOT EXISTS (select s2.id from `mysql_rest_service_metadata`.`service` s2 where s.url_host_id=s2.url_host_id AND s.url_context_root=s2.url_context_root
        AND JSON_OVERLAPS(r.options->'$.developer', s2.in_development->>'$.developers'))))
    OR
    ((published = 0) AND (s.id IN (select s2.id from `mysql_rest_service_metadata`.`service` s2 where s.url_host_id=s2.url_host_id AND s.url_context_root=s2.url_context_root
        AND JSON_OVERLAPS(r.options->'$.developer', s2.in_development->>'$.developers'))))
    OR
    ((published = 0) AND r.options->'$.developer' IS NOT NULL AND s.in_development IS NULL)
    );
USE `mysql_rest_service_metadata`;

DELIMITER $$
USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`url_host_BEFORE_DELETE` BEFORE DELETE ON `url_host` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`url_host_alias` WHERE `url_host_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`service_BEFORE_INSERT` BEFORE INSERT ON `service` FOR EACH ROW
BEGIN
    # Check if the full service request_path (including the optional developer setting) already exists
    IF NEW.enabled = TRUE THEN
        SET @host_name := (SELECT h.name FROM `mysql_rest_service_metadata`.url_host h WHERE h.id = NEW.url_host_id);
        SET @request_path := CONCAT(COALESCE(NEW.in_development->>'$.developers', ''), @host_name, NEW.url_context_root);
        SET @validPath := (SELECT `mysql_rest_service_metadata`.`valid_request_path`(@request_path));

        IF @validPath = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "The request_path is already used by another entity.";
        END IF;

        # Check if the same developer is already registered in the in_development->>'$.developers' of a service with the very same host_ctx
        SET @validDeveloperList := (SELECT MAX(COALESCE(
                JSON_OVERLAPS(s.in_development->>'$.developers', NEW.in_development->>'$.developers'), FALSE)) AS overlap
            FROM `mysql_rest_service_metadata`.`service` AS s JOIN
                `mysql_rest_service_metadata`.`url_host` AS h ON s.url_host_id = h.id JOIN
                `mysql_rest_service_metadata`.`url_host` AS h2 ON h2.id = NEW.url_host_id
            WHERE CONCAT(h.name, s.url_context_root) = CONCAT(h2.name, NEW.url_context_root) AND s.enabled = TRUE
            GROUP BY CONCAT(h.name, s.url_context_root));

        IF COALESCE(@validDeveloperList, FALSE) = TRUE THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "This developer is already registered for a REST service with the same host/url_context_root path.";
        END IF;
    END IF;

    IF NEW.in_development IS NOT NULL THEN
        SET NEW.published = 0;
    END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`service_BEFORE_UPDATE` BEFORE UPDATE ON `service` FOR EACH ROW
BEGIN
    # Check if the full service request_path (including the optional developer setting) already exists,
    # but only when the service is enabled and either of those values was actually changed
    IF NEW.enabled = TRUE AND (COALESCE(NEW.in_development, '') <> COALESCE(OLD.in_development, '')
		OR NEW.url_host_id <> OLD.url_host_id OR NEW.url_context_root <> OLD.url_context_root) THEN

        SET @host_name := (SELECT h.name FROM `mysql_rest_service_metadata`.url_host h WHERE h.id = NEW.url_host_id);
        SET @request_path := CONCAT(COALESCE(NEW.in_development->>'$.developers', ''), @host_name, NEW.url_context_root);
        SET @validPath := (SELECT `mysql_rest_service_metadata`.`valid_request_path`(@request_path));

        IF @validPath = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "The request_path is already used by another entity.";
        END IF;

        # Check if the same developer is already registered in the in_development->>'$.developers' of a service with the very same host_ctx
        SET @validDeveloperList := (SELECT MAX(COALESCE(
                JSON_OVERLAPS(s.in_development->>'$.developers', NEW.in_development->>'$.developers'), FALSE)) AS overlap
            FROM `mysql_rest_service_metadata`.`service` AS s JOIN
                `mysql_rest_service_metadata`.`url_host` AS h ON s.url_host_id = h.id JOIN
                `mysql_rest_service_metadata`.`url_host` AS h2 ON h2.id = NEW.url_host_id
            WHERE CONCAT(h.name, s.url_context_root) = CONCAT(h2.name, NEW.url_context_root) AND s.enabled = TRUE
                AND s.id <> NEW.id
            GROUP BY CONCAT(h.name, s.url_context_root));

        IF COALESCE(@validDeveloperList, FALSE) = TRUE THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "This developer is already registered for a REST service with the same host/url_context_root path.";
        END IF;
    END IF;

    IF OLD.in_development IS NULL AND NEW.in_development IS NOT NULL AND NEW.published = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "A REST service that is in development cannot be published. Please reset the development state first.";
    END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`service_BEFORE_DELETE` BEFORE DELETE ON `service` FOR EACH ROW
BEGIN
	# Since FKs do not fire the triggers on the related tables, manually trigger the DELETEs
	DELETE FROM `mysql_rest_service_metadata`.`db_schema` WHERE `service_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`content_set` WHERE `service_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`service_has_auth_app` WHERE `service_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`mrs_role` WHERE `specific_to_service_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`mrs_user_hierarchy_type` WHERE `specific_to_service_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`mrs_user_group` WHERE `specific_to_service_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`db_schema_BEFORE_INSERT` BEFORE INSERT ON `db_schema` FOR EACH ROW
BEGIN
	SET @service_path := (SELECT CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root) AS path
		FROM `mysql_rest_service_metadata`.service se
            LEFT JOIN `mysql_rest_service_metadata`.url_host h
                ON se.url_host_id = h.id
		WHERE se.id = NEW.service_id);
	SET @validPath := (SELECT `mysql_rest_service_metadata`.`valid_request_path`(CONCAT(@service_path, NEW.request_path)));

    IF @validPath = 0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "The request_path is already used by another entity.";
    END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`db_schema_BEFORE_UPDATE` BEFORE UPDATE ON `db_schema` FOR EACH ROW
BEGIN
	IF (NEW.request_path <> OLD.request_path OR NEW.service_id <> OLD.service_id) THEN
		SET @service_path := (SELECT CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root) AS path
			FROM `mysql_rest_service_metadata`.service se
				LEFT JOIN `mysql_rest_service_metadata`.url_host h
					ON se.url_host_id = h.id
			WHERE se.id = NEW.service_id);
		SET @validPath := (SELECT `mysql_rest_service_metadata`.`valid_request_path`(CONCAT(@service_path, NEW.request_path)));

		IF @validPath = 0 THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "The request_path is already used by another entity.";
		END IF;
    END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`db_schema_BEFORE_DELETE` BEFORE DELETE ON `db_schema` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`db_object` WHERE `db_schema_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`mrs_privilege` WHERE `db_schema_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`db_object_BEFORE_INSERT` BEFORE INSERT ON `db_object` FOR EACH ROW
BEGIN
    SET @schema_path := (SELECT CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root, sc.request_path) AS path
        FROM `mysql_rest_service_metadata`.db_schema sc
            LEFT OUTER JOIN `mysql_rest_service_metadata`.service se
                ON se.id = sc.service_id
            LEFT JOIN `mysql_rest_service_metadata`.url_host h
                ON se.url_host_id = h.id
        WHERE sc.id = NEW.db_schema_id);
    SET @validPath := (SELECT `mysql_rest_service_metadata`.`valid_request_path`(CONCAT(@schema_path, NEW.request_path)));

    IF @validPath = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "The request_path is already used by another entity.";
    END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`db_object_BEFORE_UPDATE` BEFORE UPDATE ON `db_object` FOR EACH ROW
BEGIN
    IF (NEW.request_path <> OLD.request_path OR NEW.db_schema_id <> OLD.db_schema_id) THEN
        SET @schema_path := (SELECT CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root, sc.request_path) AS path
            FROM `mysql_rest_service_metadata`.db_schema sc
                LEFT OUTER JOIN `mysql_rest_service_metadata`.service se
                    ON se.id = sc.service_id
                LEFT JOIN `mysql_rest_service_metadata`.url_host h
                    ON se.url_host_id = h.id
            WHERE sc.id = NEW.db_schema_id);
        SET @validPath := (SELECT `mysql_rest_service_metadata`.`valid_request_path`(CONCAT(@schema_path, NEW.request_path)));

        IF @validPath = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "The request_path is already used by another entity.";
        END IF;
    END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`db_object_BEFORE_DELETE` BEFORE DELETE ON `db_object` FOR EACH ROW
BEGIN
    DELETE FROM `mysql_rest_service_metadata`.`mrs_privilege` WHERE `db_object_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`mrs_db_object_row_group_security` WHERE `db_object_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`object` WHERE `db_object_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`auth_vendor_BEFORE_DELETE` BEFORE DELETE ON `auth_vendor` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`auth_app` WHERE `auth_vendor_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`auth_app_BEFORE_DELETE` BEFORE DELETE ON `auth_app` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`mrs_user` WHERE `auth_app_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`mrs_user_BEFORE_INSERT` BEFORE INSERT ON `mrs_user` FOR EACH ROW
BEGIN
	IF NEW.name IS NOT NULL AND (SELECT COUNT(*) FROM `mysql_rest_service_metadata`.`mrs_user` AS u
		WHERE UPPER(u.name) = UPPER(NEW.name) AND u.auth_app_id = NEW.auth_app_id AND NEW.id <> u.id) > 0
	THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "This name has already been used.";
	END IF;
	IF NEW.email IS NOT NULL AND (SELECT COUNT(*) FROM `mysql_rest_service_metadata`.`mrs_user` AS u
		WHERE UPPER(u.email) = UPPER(NEW.email) AND u.auth_app_id = NEW.auth_app_id AND NEW.id <> u.id) > 0
	THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "This email has already been used.";
    END IF;
    IF (NEW.auth_string IS NULL AND
        (SELECT a.auth_vendor_id FROM `mysql_rest_service_metadata`.`auth_app` AS a WHERE a.id = NEW.auth_app_id) = 0x30000000000000000000000000000000)
    THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "A this account requires a password to be set.";
    END IF;
    IF JSON_STORAGE_SIZE(NEW.app_options) > 16384 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "The JSON value stored in app_options must not be bigger than 16KB.";
    END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`mrs_user_BEFORE_UPDATE` BEFORE UPDATE ON `mrs_user` FOR EACH ROW
BEGIN
	IF NEW.name IS NOT NULL AND (SELECT COUNT(*) FROM `mysql_rest_service_metadata`.`mrs_user` AS u
		WHERE UPPER(u.name) = UPPER(NEW.name) AND u.auth_app_id = NEW.auth_app_id AND NEW.id <> u.id) > 0
	THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "This name has already been used.";
	END IF;
	IF NEW.email IS NOT NULL AND (SELECT COUNT(*) FROM `mysql_rest_service_metadata`.`mrs_user` AS u
		WHERE UPPER(u.email) = UPPER(NEW.email) AND u.auth_app_id = NEW.auth_app_id AND NEW.id <> u.id) > 0
	THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "This email has already been used.";
    END IF;
    IF (NEW.auth_string IS NULL AND
        (SELECT a.auth_vendor_id FROM `mysql_rest_service_metadata`.`auth_app` AS a WHERE a.id = NEW.auth_app_id) = 0x30000000000000000000000000000000)
    THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "A this account requires a password to be set.";
    END IF;
    IF JSON_STORAGE_SIZE(NEW.app_options) > 16384 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "The JSON value stored in app_options must not be bigger than 16KB.";
    END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`mrs_user_BEFORE_DELETE` BEFORE DELETE ON `mrs_user` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`mrs_user_hierarchy` WHERE `user_id` = OLD.`id` OR `reporting_to_user_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`mrs_user_has_role` WHERE `user_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`mrs_user_has_group` WHERE `user_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`content_set_BEFORE_INSERT` BEFORE INSERT ON `content_set` FOR EACH ROW
BEGIN
	SET @service_path := (SELECT CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root) AS path
		FROM `mysql_rest_service_metadata`.service se
            LEFT JOIN `mysql_rest_service_metadata`.url_host h
                ON se.url_host_id = h.id
		WHERE se.id = NEW.service_id);
	SET @validPath := (SELECT `mysql_rest_service_metadata`.`valid_request_path`(CONCAT(@service_path, NEW.request_path)));

    IF @validPath = 0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "The request_path is already used by another entity.";
    END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`content_set_BEFORE_UPDATE` BEFORE UPDATE ON `content_set` FOR EACH ROW
BEGIN
	IF (NEW.request_path <> OLD.request_path OR NEW.service_id <> OLD.service_id) THEN
		SET @service_path := (SELECT CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root) AS path
			FROM `mysql_rest_service_metadata`.service se
				LEFT JOIN `mysql_rest_service_metadata`.url_host h
					ON se.url_host_id = h.id
			WHERE se.id = NEW.service_id);
		SET @validPath := (SELECT `mysql_rest_service_metadata`.`valid_request_path`(CONCAT(@service_path, NEW.request_path)));

		IF @validPath = 0 THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "The request_path is already used by another entity.";
		END IF;
    END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`content_set_BEFORE_DELETE` BEFORE DELETE ON `content_set` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`content_file`
	WHERE `content_set_id` = OLD.`id`;
	DELETE FROM `mysql_rest_service_metadata`.`content_set_has_obj_def`
	WHERE `content_set_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`content_file_BEFORE_INSERT` BEFORE INSERT ON `content_file` FOR EACH ROW
BEGIN
    SET @content_set_path := (SELECT CONCAT(h.name, se.url_context_root, co.request_path) AS path
        FROM `mysql_rest_service_metadata`.content_set co
            LEFT OUTER JOIN `mysql_rest_service_metadata`.service se
                ON se.id = co.service_id
            LEFT JOIN `mysql_rest_service_metadata`.url_host h
                ON se.url_host_id = h.id
        WHERE co.id = NEW.content_set_id);
    SET @validPath := (SELECT `mysql_rest_service_metadata`.`valid_request_path`(CONCAT(@content_set_path, NEW.request_path)));

    IF @validPath = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "The request_path is already used by another entity.";
    END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`content_file_BEFORE_UPDATE` BEFORE UPDATE ON `content_file` FOR EACH ROW
BEGIN
    IF (NEW.request_path <> OLD.request_path OR NEW.content_set_id <> OLD.content_set_id) THEN
        SET @content_set_path := (SELECT CONCAT(h.name, se.url_context_root, co.request_path) AS path
            FROM `mysql_rest_service_metadata`.content_set co
                LEFT OUTER JOIN `mysql_rest_service_metadata`.service se
                    ON se.id = co.service_id
                LEFT JOIN `mysql_rest_service_metadata`.url_host h
                    ON se.url_host_id = h.id
            WHERE co.id = NEW.content_set_id);
        SET @validPath := (SELECT `mysql_rest_service_metadata`.`valid_request_path`(CONCAT(@content_set_path, NEW.request_path)));

        IF @validPath = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "The request_path is already used by another entity.";
        END IF;
    END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`mrs_role_BEFORE_DELETE` BEFORE DELETE ON `mrs_role` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`mrs_user_has_role` WHERE `role_id` = OLD.`id`;
    -- Workaround to fix issue with recursive delete
	IF OLD.id <> NULL THEN
		DELETE FROM `mysql_rest_service_metadata`.`mrs_role` WHERE `derived_from_role_id` = OLD.`id`;
	END IF;
    DELETE FROM `mysql_rest_service_metadata`.`mrs_privilege` WHERE `role_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`mrs_user_group_has_role` WHERE `role_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`mrs_user_hierarchy_type_BEFORE_DELETE` BEFORE DELETE ON `mrs_user_hierarchy_type` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`mrs_user_hierarchy` WHERE `user_hierarchy_type_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`mrs_user_group_BEFORE_DELETE` BEFORE DELETE ON `mrs_user_group` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`mrs_user_has_group` WHERE `user_group_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`mrs_user_group_hierarchy` WHERE `user_group_id` = OLD.`id` OR `parent_group_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`mrs_user_group_has_role` WHERE `user_group_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`mrs_group_hierarchy_type_BEFORE_DELETE` BEFORE DELETE ON `mrs_group_hierarchy_type` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`mrs_user_group_hierarchy` WHERE `group_hierarchy_type_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`mrs_db_object_row_group_security` WHERE `group_hierarchy_type_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`router_BEFORE_DELETE` BEFORE DELETE ON `router` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`router_status` WHERE `router_id` = OLD.`id`;
    DELETE FROM `mysql_rest_service_metadata`.`router_general_log` WHERE `router_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`router_session_BEFORE_DELETE` BEFORE DELETE ON `router_session` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`router_general_log` WHERE `router_session_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`object_BEFORE_DELETE` BEFORE DELETE ON `object` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`object_field` WHERE `object_id` = OLD.`id`;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`object_field_BEFORE_DELETE` BEFORE DELETE ON `object_field` FOR EACH ROW
BEGIN
	SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
	DELETE FROM `mysql_rest_service_metadata`.`object_reference` WHERE `id` = OLD.`represents_reference_id`;
    SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`service_has_auth_app_AFTER_DELETE` AFTER DELETE ON `service_has_auth_app` FOR EACH ROW
BEGIN
	# Since FKs do not fire the triggers on the related tables, manually trigger the DELETEs
    # If the corresponding auth_app is not used by another service, delete it
	IF ((SELECT COUNT(*) FROM `mysql_rest_service_metadata`.`service_has_auth_app` WHERE auth_app_id = OLD.auth_app_id) = 0) THEN
		DELETE FROM `mysql_rest_service_metadata`.`auth_app` WHERE `id` = OLD.`auth_app_id`;
	END IF;
END$$

USE `mysql_rest_service_metadata`$$
CREATE DEFINER = CURRENT_USER TRIGGER `mysql_rest_service_metadata`.`content_set_has_obj_def_BEFORE_DELETE` BEFORE DELETE ON `content_set_has_obj_def` FOR EACH ROW
BEGIN
	DELETE FROM `mysql_rest_service_metadata`.`db_object` dbo
    WHERE OLD.method_type = "Script" AND dbo.id = OLD.db_object_id;
END$$


DELIMITER ;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

-- -----------------------------------------------------
-- Data for table `mysql_rest_service_metadata`.`auth_vendor`
-- -----------------------------------------------------
START TRANSACTION;
USE `mysql_rest_service_metadata`;
INSERT INTO `mysql_rest_service_metadata`.`auth_vendor` (`id`, `name`, `validation_url`, `enabled`, `comments`, `options`) VALUES (0x30, 'MRS', NULL, 1, 'Built-in user management of MRS', NULL);
INSERT INTO `mysql_rest_service_metadata`.`auth_vendor` (`id`, `name`, `validation_url`, `enabled`, `comments`, `options`) VALUES (0x31, 'MySQL Internal', NULL, 1, 'Provides basic authentication via MySQL Server accounts', NULL);
INSERT INTO `mysql_rest_service_metadata`.`auth_vendor` (`id`, `name`, `validation_url`, `enabled`, `comments`, `options`) VALUES (0x32, 'Facebook', NULL, 1, 'Uses the Facebook Login OAuth2 service', NULL);
INSERT INTO `mysql_rest_service_metadata`.`auth_vendor` (`id`, `name`, `validation_url`, `enabled`, `comments`, `options`) VALUES (0x34, 'Google', NULL, 1, 'Uses the Google OAuth2 service', NULL);

COMMIT;


-- -----------------------------------------------------
-- Data for table `mysql_rest_service_metadata`.`config`
-- -----------------------------------------------------
START TRANSACTION;
USE `mysql_rest_service_metadata`;
INSERT INTO `mysql_rest_service_metadata`.`config` (`id`, `service_enabled`, `data`) VALUES (1, 1, '{\n    \"defaultStaticContent\": {\n        \"index.html\": \"PCFET0NUWVBFIGh0bWw+PGh0bWw+PGhlYWQ+IDx0aXRsZT5NeVNRTCBSRVNUIFNlcnZpY2U8L3RpdGxlPiA8bGluayByZWw9Imljb24iIHR5cGU9ImltYWdlL3N2Zyt4bWwiIGhyZWY9Ii4vZmF2aWNvbi5zdmciPiA8c3R5bGU+OnJvb3R7LS1ib2R5LWJhY2tncm91bmQ6IGhzbCgyNDAsIDUlLCA5MSUpOyAtLWJvZHktdGV4dC1jb2xvcjogaHNsKDI0MCwgNSUsIDEyJSk7IC0taWNvbi1jb2xvcjogaHNsKDIwMCwgNjUlLCA0MCUpOyAtLXRleHRMaW5rLWZvcmVncm91bmQ6IGhzbCgyMDAsIDY1JSwgMzQlKTt9QG1lZGlhIChwcmVmZXJzLWNvbG9yLXNjaGVtZTogZGFyayl7OnJvb3R7LS1ib2R5LWJhY2tncm91bmQ6IGhzbCgwLCAwJSwgMTclKTsgLS1ib2R5LXRleHQtY29sb3I6IGhzbCgwLCAwJSwgNzUlKTsgLS10ZXh0TGluay1mb3JlZ3JvdW5kOiBoc2woMjAwLCA2NSUsIDU0JSk7fX1odG1sLCBib2R5e3dpZHRoOiAxMDAlOyBoZWlnaHQ6IDEwMCU7fSp7bWFyZ2luOiAwOyBwYWRkaW5nOiAwO31ib2R5e292ZXJmbG93OiBoaWRkZW47IGJhY2tncm91bmQtY29sb3I6IHZhcigtLWJvZHktYmFja2dyb3VuZCk7IGZvbnQtZmFtaWx5OiAiSGVsdmV0aWNhIE5ldWUiLCBIZWx2ZXRpY2EsIEFyaWFsLCBzYW5zLXNlcmlmOyBmb250LXNpemU6IDEycHg7IGNvbG9yOiB2YXIoLS1ib2R5LXRleHQtY29sb3IpO31oMnttYXJnaW46IDIwcHggMDsgZm9udC13ZWlnaHQ6IDEwMDsgZm9udC1zaXplOiAzM3B4O31we2xpbmUtaGVpZ2h0OiAxOXB4OyBmb250LXdlaWdodDogMjAwOyBmb250LXNpemU6IDE1cHg7fWF7Y29sb3I6IHZhcigtLXRleHRMaW5rLWZvcmVncm91bmQpOyB0ZXh0LWRlY29yYXRpb246IG5vbmU7IGZvbnQtd2VpZ2h0OiA1MDA7IHBhZGRpbmc6IDAgMjBweDsgZm9udC1zaXplOiAxNXB4O30ud2VsY29tZVBhbmVse2Rpc3BsYXk6IGZsZXg7IHdpZHRoOiAxMDAlOyBoZWlnaHQ6IDEwMCU7IGZsZXgtZGlyZWN0aW9uOiBjb2x1bW47IGFsaWduLWl0ZW1zOiBjZW50ZXI7IGp1c3RpZnktY29udGVudDogY2VudGVyO30ud2VsY29tZUxvZ297bWFyZ2luLXRvcDogMjBweDsgd2lkdGg6IDE2MHB4OyBoZWlnaHQ6IDE2MHB4OyBtaW4taGVpZ2h0OiAxNjBweDsgYmFja2dyb3VuZC1jb2xvcjogdmFyKC0taWNvbi1jb2xvcik7IC13ZWJraXQtbWFzay1pbWFnZTogdXJsKCJkYXRhOmltYWdlL3N2Zyt4bWwsJTNDc3ZnIHhtbG5zPSdodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2Zycgd2lkdGg9JzEwMCUyNScgaGVpZ2h0PScxMDAlMjUnIHZpZXdCb3g9JzAgMCAxMjggMTI4JyBmaWxsLXJ1bGU9J2V2ZW5vZGQnIHN0cm9rZS1saW5lam9pbj0ncm91bmQnIHN0cm9rZS1taXRlcmxpbWl0PScyJyB4bWxuczp2PSdodHRwczovL3ZlY3RhLmlvL25hbm8nJTNFJTNDcGF0aCBkPSdNNjAuMTA5IDI2LjE3M2MtLjQwNyAxLjc2Mi0uNjc4IDMuNTc4LS44IDUuNDM0LTMuNzk3LTMuNDQ1LTguMDA5LTYuNTI2LTEyLjcwOC05LjQwMi0zLjc1Ny0yLjI5MS03Ljg5My00LjQwNy0xMi41MDgtNS43NjQtMi42MTEtLjc2OC01LjQ4My0uOTA3LTguNTM4LS45NjQtLjU5NS0uMDExLTEuMTkgMC0xLjc4NiAwLTEuNTY2LS40NDQtMi44NzQtMi4wNS00LjE3MS0yLjg4LTIuNjk3LTEuNzM0LTUuMzUzLTIuOTUtOC41MzUtNC4yMy0xLjIwMS0uNDgtMy43OTUtMS42MjYtNS41NTktLjc3LS41NzQuMjc5LS45MjYuNTU5LTEuMTkgMS4xNS0uNDg0IDEuMDktLjA1OCAxLjUxMy4zOTcgMi40NjQgMS4yNzYgMi42ODIgMy4xMTkgNC4zMiA0Ljc2NiA2LjU0MSAxLjQ4NSAyLjAwMSAzLjI5NiA0LjI3OSA0LjM2NyA2LjUzNyAyLjIzOCA0LjcwOCAzLjIzMiA5Ljk0NiA1LjM1OSAxNC42MDcuODE3IDEuNzkyIDEuOTk3IDMuODM4IDMuMTc3IDUuMzgyLjk1NiAxLjI2MSAyLjczOSAyLjUgMy4yNTUgNC4xNDcgMS4wODIgMS42NDEtLjc0NSA3LjkzNC0xLjI2MyA5Ljc0MS0yLjcyMiA5LjUyMS0yLjE3IDE0Ljg5MS43OTYgMjIuNDkyLjkzNyAyLjQwMiAyLjY1OCA1LjI4IDMuNzYzIDUuNzY2LjIzNS4xMDUuNzQ1LS4xNTYuOTA3LS40ODkgMS45MjItMy45NDUgMS4zODItOS42MDYgMi40OTQtMTIuMjE4Ljk3Ny0yLjI5MSAxLjUxOS00LjI0MSAzLjU0OC01Ljk0My44My0uNjk1IDEuMzcgMi4zMzQgMS44MTUgMy4zNTEuOTU2IDIuMTggMS45NTYgNS4yMTYgMy4zNDcgNy44MDIgMi45MTQgNS40MTcgNi4xMSAxMC42MjIgOS43MjggMTUuMzc5IDEuMjg0IDEuNjkyIDMuMDEyIDMuNTI2IDQuNTY3IDUuMDAxLjY1OS42MjcgMS41NTcgMS41NTUgMi4yOTUgMi4zMTMuMDQ3LjA0Ny00Ljg3LTMuMDQ5LTYuODQyLTQuNjc0LTMuOTMyLTMuMjQ1LTguMjk0LTcuOTM2LTEwLjk0LTEyLjA2MmwtMy41NzMtNi45MjN2LS4xODhjLS40OTkuNjQ0LS4zNDMgMS4zNDYtLjU5NyAyLjMwNC0xLjEyMiA0LjIzMy0uMjQ1IDkuMDI4LTQuMTY5IDEwLjU3OS00LjQ4NCAxLjc2OS03Ljc0Ni0yLjg1LTkuMTMzLTUuMDAxLTQuNTE0LTcuMDE0LTUuNjgzLTE4Ljc4Ni0yLjU3OS0yOC4yNTguNjg3LTIuMTA4IDEuOTI2LTQuMzU4IDEuODU4LTYuNDIzLS4wMzgtMS4xNTgtMS43ODYtMi41NTgtMi41MTctMy41MjQtMS4xOTMtMS41NzQtMS43NzMtMi43MTYtMi43MTgtNC40NzgtMS44NjUtMy40NzktMy4xMjEtNy41NzUtNC41NjUtMTEuMzQxLS41ODctMS41MjctLjcwNC0yLjk3Ni0xLjM4OS00LjQyNS0xLjA0My0yLjE5NS0yLjkxLTQuMzg2LTQuMzY5LTYuMzQ1QzQuMDIxIDE4LjA3OS0xLjc4NiAxMi43MDkuNTQyIDcuMjFjMy42ODktOC43MTMgMTYuNDYxLTIuMDg0IDIxLjQ0Ljk2MiAxLjI1Ljc2OCAyLjYzOSAyLjM0OSAzLjk3IDIuODg0IDIuMTg1LjEzMiA0LjM4NC4xMDUgNi41NTQuMzg2IDQuMTU4LjUzOCA3LjkxOSAxLjY1MSAxMS4xMTcgMy40NTggNi4zMzQgMy41ODggMTEuNzA4IDcuMjExIDE2LjQ4NiAxMS4yNzN6bTIxLjE4NiAzOS40NmEzMy43NCAzMy43NCAwIDAgMCA2LjA3MSAxLjY0M2MuNTA4IDEuMjc0Ljk5MiAyLjM5OCAxLjUyMSAzLjM3OSAxLjE4OCAyLjIyMyAyLjAyOSA0LjYzMSAzLjU3MSA2LjU0MS42NTMuODA0IDIuMzg5IDEuMDU0IDMuMzc3IDEuNTM2IDIuOTM1IDEuNDM2IDYuMzYyIDIuNTM5IDkuMTMxIDQuMjMzIDQuOTk2IDMuMDU1IDEwLjEwMSA2LjMwNCAxNC40ODUgMTAuMDQ0IDIuNTExIDIuMTQgMy4zNTYgMy41NDMgNC40MTggNS41Ny4xMjIuMjI4LTIuNzAxIDEuNDE3LTQuMDkyIDEuODAzLTMuMDgzLjc2OC01Ljk5NS44MzItOS4wNTQgMS4yMzMtMS44NTguMjQ1LTYuMjY4LjM4Ni01Ljk1NiAxLjM0NC43NTkgMi4zMjcgNy40MDkgNS44MDMgMTAuMTI1IDcuNjkxIDMuNDA3IDIuMzY2IDUuODE4IDQuNzE3IDkuMjE0IDcuODkxLjg3NS44MTkgMS42ODUgMS44NzUgMi41IDMuMDYzLjU3Mi44MzYgMS40NTEgMi45MTQgMS4zOTEgMi44ODktMS4yMDEtLjQ4LTEuODQ3LTEuNDUzLTIuNzgtMi4xMTQtMS44OTItMS4zNDQtMy44MTktMi44NS01Ljc1OC00LjAzOC0zLjI5LTIuMDItNy4xMDYtMy4xNy0xMC41MjItNS4xODgtMS45MjItMS4xMzctMy43NjUtMi41MzctNS41NTktMy44NTEtMS42MzgtMS4xOTctMy40NzktMy40ODQtNC41NjUtNS4xODgtLjU2Ny0uODktMS4yNjUtMi4wMzMtMS4zOTEtMi42OS0uMjk3LTEuNTYyIDIuMjQ2LTEuODk0IDMuNTgyLTIuMzEzIDQuNjE3LTEuNDQgMTcuMzY3LTEuOTc1IDE3LjM2Ny0xLjk3NS0yLjAyNy0xLjc0OS01LjA0Ny0zLjk4MS02LjQ1NS00Ljk0My0yLjgyLTEuOTIyLTUuNjMtMy44MDgtOC42MzYtNS41NTktMS41NzQtLjkxNy00LjM5NS0xLjgzNy02LjA1Ny0yLjUxNy0yLjM2OC0uOTY2LTcuNTg0LTEuOTA1LTguOTM0LTMuNjQ4LTIuNTY2LTMuMzIyLTMuMDI5LTUuNTM4LTQuODQ1LTkuNTMyLS42NC0xLjQwNi0xLjI5NS0zLjE1MS0yLjE1LTUuMzAxek0yOS4xMzEgMjMuNzQ1YTUuODYgNS44NiAwIDAgMSAyLjM4MSAxLjkyNGMuNDI3LjU5NS42MDIgMS4xMi44MzggMS45OTcuNTI5IDEuOTc1LTEuNzY0IDQuMDktMS44MyA0LjE1MS0uNjYxLTEuMzQ0LS41NjEtMS41NjYtMS45ODYtNC4wMzQtMS41MTktMi42My0yLjk3OC0zLjU4Ni0yLjk3OC0zLjY1MiAxLjA5LS4yMzMgMi4xOTEtLjk2NiAzLjU3NS0uMzg2ek05My4yMzMgMy42MDZjMTYuNjc4IDAgMzAuMjE4IDEzLjU0IDMwLjIxOCAzMC4yMThzLTEzLjU0IDMwLjIxOS0zMC4yMTggMzAuMjE5LTMwLjIxOC0xMy41NDEtMzAuMjE4LTMwLjIxOVM3Ni41NTUgMy42MDYgOTMuMjMzIDMuNjA2em0wIDMuNzU4Yy0xNC42MDQgMC0yNi40NjEgMTEuODU3LTI2LjQ2MSAyNi40NjFzMTEuODU3IDI2LjQ2MSAyNi40NjEgMjYuNDYxIDI2LjQ2MS0xMS44NTcgMjYuNDYxLTI2LjQ2MVMxMDcuODM3IDcuMzY0IDkzLjIzMyA3LjM2NHonIGZpbGw9JyUyMzAwNWE4NScvJTNFJTNDcGF0aCBkPSdNNC42MjcgMTYuMTIyaC4zNzZ2LS44OTJoLS4yNTVjLS40MDkgMC0uNzAzLS4wODktLjg4MS0uMjY1cy0uMjY4LS40NjktLjI2OC0uODh2LTEuNjI5YzAtLjM4NS0uMTItLjY4NC0uMzU4LS44OTVzLS41OTQtLjM0LTEuMDY1LS4zODN2LS4xNDRjLjQ3MS0uMDQzLjgyNS0uMTcxIDEuMDY1LS4zODVzLjM1OC0uNTEzLjM1OC0uODk4VjguMTQ0YzAtLjQxLjA4OS0uNzAyLjI2OC0uODc5UzQuMzM5IDcgNC43NDggN2guMjU1di0uODkyaC0uMzc2Yy0uNzg3IDAtMS4zNjQuMTUzLTEuNzMuNDZzLS41NS43ODUtLjU1IDEuNDM3djEuMzg0YzAgLjQxNy0uMTAyLjcwOC0uMzA0Ljg3M3MtLjU2LjI0OS0xLjA3MS4yNDl2MS4xODZjLjUxMS4wMDMuODY4LjA4OCAxLjA3MS4yNTNzLjMwNC40NTUuMzA0Ljg2OHYxLjQwMWMwIC42NTEuMTg0IDEuMTMyLjU1IDEuNDM5cy45NDMuNDYzIDEuNzMuNDYzem0yLjY0OCAwYy43ODIgMCAxLjM1NS0uMTU0IDEuNzItLjQ2M3MuNTQ3LS43ODguNTQ3LTEuNDM5di0xLjQwMWMwLS40MTMuMS0uNzAyLjMwMi0uODY4cy41NTctLjI1IDEuMDYzLS4yNTN2LTEuMTg2Yy0uNTA3IDAtLjg2Mi0uMDgzLTEuMDYzLS4yNDlzLS4zMDItLjQ1Ny0uMzAyLS44NzNWOC4wMDVjMC0uNjUyLS4xODMtMS4xMzEtLjU0Ny0xLjQzN3MtLjkzOS0uNDYtMS43Mi0uNDZINi45VjdoLjI1NWMuNDEgMCAuNzA0LjA4OS44OC4yNjVzLjI2My40NjkuMjYzLjg3OXYxLjYwOGMwIC4zODYuMTE4LjY4NS4zNTYuODk4cy41OTMuMzQyIDEuMDYzLjM4NXYuMTQ0Yy0uNDcuMDQzLS44MjUuMTcxLTEuMDYzLjM4M3MtLjM1Ni41MTEtLjM1Ni44OTV2MS42MjljMCAuNDExLS4wOS43MDQtLjI2Ni44OHMtLjQ2OS4yNjUtLjg3Ni4yNjVINi45di44OTJoLjM3NXonIHRyYW5zZm9ybT0nbWF0cml4KDMuNzgxNTcgMCAwIDMuNzgxNTcgNzAuNzU5NiAtOC4yNTYwNCknIGZpbGw9JyUyMzAwNWE4NScgZmlsbC1ydWxlPSdub256ZXJvJy8lM0UlM0Mvc3ZnJTNFIik7IG1hc2staW1hZ2U6IHVybCgiZGF0YTppbWFnZS9zdmcreG1sLCUzQ3N2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnIHdpZHRoPScxMDAlMjUnIGhlaWdodD0nMTAwJTI1JyB2aWV3Qm94PScwIDAgMTI4IDEyOCcgZmlsbC1ydWxlPSdldmVub2RkJyBzdHJva2UtbGluZWpvaW49J3JvdW5kJyBzdHJva2UtbWl0ZXJsaW1pdD0nMicgeG1sbnM6dj0naHR0cHM6Ly92ZWN0YS5pby9uYW5vJyUzRSUzQ3BhdGggZD0nTTYwLjEwOSAyNi4xNzNjLS40MDcgMS43NjItLjY3OCAzLjU3OC0uOCA1LjQzNC0zLjc5Ny0zLjQ0NS04LjAwOS02LjUyNi0xMi43MDgtOS40MDItMy43NTctMi4yOTEtNy44OTMtNC40MDctMTIuNTA4LTUuNzY0LTIuNjExLS43NjgtNS40ODMtLjkwNy04LjUzOC0uOTY0LS41OTUtLjAxMS0xLjE5IDAtMS43ODYgMC0xLjU2Ni0uNDQ0LTIuODc0LTIuMDUtNC4xNzEtMi44OC0yLjY5Ny0xLjczNC01LjM1My0yLjk1LTguNTM1LTQuMjMtMS4yMDEtLjQ4LTMuNzk1LTEuNjI2LTUuNTU5LS43Ny0uNTc0LjI3OS0uOTI2LjU1OS0xLjE5IDEuMTUtLjQ4NCAxLjA5LS4wNTggMS41MTMuMzk3IDIuNDY0IDEuMjc2IDIuNjgyIDMuMTE5IDQuMzIgNC43NjYgNi41NDEgMS40ODUgMi4wMDEgMy4yOTYgNC4yNzkgNC4zNjcgNi41MzcgMi4yMzggNC43MDggMy4yMzIgOS45NDYgNS4zNTkgMTQuNjA3LjgxNyAxLjc5MiAxLjk5NyAzLjgzOCAzLjE3NyA1LjM4Mi45NTYgMS4yNjEgMi43MzkgMi41IDMuMjU1IDQuMTQ3IDEuMDgyIDEuNjQxLS43NDUgNy45MzQtMS4yNjMgOS43NDEtMi43MjIgOS41MjEtMi4xNyAxNC44OTEuNzk2IDIyLjQ5Mi45MzcgMi40MDIgMi42NTggNS4yOCAzLjc2MyA1Ljc2Ni4yMzUuMTA1Ljc0NS0uMTU2LjkwNy0uNDg5IDEuOTIyLTMuOTQ1IDEuMzgyLTkuNjA2IDIuNDk0LTEyLjIxOC45NzctMi4yOTEgMS41MTktNC4yNDEgMy41NDgtNS45NDMuODMtLjY5NSAxLjM3IDIuMzM0IDEuODE1IDMuMzUxLjk1NiAyLjE4IDEuOTU2IDUuMjE2IDMuMzQ3IDcuODAyIDIuOTE0IDUuNDE3IDYuMTEgMTAuNjIyIDkuNzI4IDE1LjM3OSAxLjI4NCAxLjY5MiAzLjAxMiAzLjUyNiA0LjU2NyA1LjAwMS42NTkuNjI3IDEuNTU3IDEuNTU1IDIuMjk1IDIuMzEzLjA0Ny4wNDctNC44Ny0zLjA0OS02Ljg0Mi00LjY3NC0zLjkzMi0zLjI0NS04LjI5NC03LjkzNi0xMC45NC0xMi4wNjJsLTMuNTczLTYuOTIzdi0uMTg4Yy0uNDk5LjY0NC0uMzQzIDEuMzQ2LS41OTcgMi4zMDQtMS4xMjIgNC4yMzMtLjI0NSA5LjAyOC00LjE2OSAxMC41NzktNC40ODQgMS43NjktNy43NDYtMi44NS05LjEzMy01LjAwMS00LjUxNC03LjAxNC01LjY4My0xOC43ODYtMi41NzktMjguMjU4LjY4Ny0yLjEwOCAxLjkyNi00LjM1OCAxLjg1OC02LjQyMy0uMDM4LTEuMTU4LTEuNzg2LTIuNTU4LTIuNTE3LTMuNTI0LTEuMTkzLTEuNTc0LTEuNzczLTIuNzE2LTIuNzE4LTQuNDc4LTEuODY1LTMuNDc5LTMuMTIxLTcuNTc1LTQuNTY1LTExLjM0MS0uNTg3LTEuNTI3LS43MDQtMi45NzYtMS4zODktNC40MjUtMS4wNDMtMi4xOTUtMi45MS00LjM4Ni00LjM2OS02LjM0NUM0LjAyMSAxOC4wNzktMS43ODYgMTIuNzA5LjU0MiA3LjIxYzMuNjg5LTguNzEzIDE2LjQ2MS0yLjA4NCAyMS40NC45NjIgMS4yNS43NjggMi42MzkgMi4zNDkgMy45NyAyLjg4NCAyLjE4NS4xMzIgNC4zODQuMTA1IDYuNTU0LjM4NiA0LjE1OC41MzggNy45MTkgMS42NTEgMTEuMTE3IDMuNDU4IDYuMzM0IDMuNTg4IDExLjcwOCA3LjIxMSAxNi40ODYgMTEuMjczem0yMS4xODYgMzkuNDZhMzMuNzQgMzMuNzQgMCAwIDAgNi4wNzEgMS42NDNjLjUwOCAxLjI3NC45OTIgMi4zOTggMS41MjEgMy4zNzkgMS4xODggMi4yMjMgMi4wMjkgNC42MzEgMy41NzEgNi41NDEuNjUzLjgwNCAyLjM4OSAxLjA1NCAzLjM3NyAxLjUzNiAyLjkzNSAxLjQzNiA2LjM2MiAyLjUzOSA5LjEzMSA0LjIzMyA0Ljk5NiAzLjA1NSAxMC4xMDEgNi4zMDQgMTQuNDg1IDEwLjA0NCAyLjUxMSAyLjE0IDMuMzU2IDMuNTQzIDQuNDE4IDUuNTcuMTIyLjIyOC0yLjcwMSAxLjQxNy00LjA5MiAxLjgwMy0zLjA4My43NjgtNS45OTUuODMyLTkuMDU0IDEuMjMzLTEuODU4LjI0NS02LjI2OC4zODYtNS45NTYgMS4zNDQuNzU5IDIuMzI3IDcuNDA5IDUuODAzIDEwLjEyNSA3LjY5MSAzLjQwNyAyLjM2NiA1LjgxOCA0LjcxNyA5LjIxNCA3Ljg5MS44NzUuODE5IDEuNjg1IDEuODc1IDIuNSAzLjA2My41NzIuODM2IDEuNDUxIDIuOTE0IDEuMzkxIDIuODg5LTEuMjAxLS40OC0xLjg0Ny0xLjQ1My0yLjc4LTIuMTE0LTEuODkyLTEuMzQ0LTMuODE5LTIuODUtNS43NTgtNC4wMzgtMy4yOS0yLjAyLTcuMTA2LTMuMTctMTAuNTIyLTUuMTg4LTEuOTIyLTEuMTM3LTMuNzY1LTIuNTM3LTUuNTU5LTMuODUxLTEuNjM4LTEuMTk3LTMuNDc5LTMuNDg0LTQuNTY1LTUuMTg4LS41NjctLjg5LTEuMjY1LTIuMDMzLTEuMzkxLTIuNjktLjI5Ny0xLjU2MiAyLjI0Ni0xLjg5NCAzLjU4Mi0yLjMxMyA0LjYxNy0xLjQ0IDE3LjM2Ny0xLjk3NSAxNy4zNjctMS45NzUtMi4wMjctMS43NDktNS4wNDctMy45ODEtNi40NTUtNC45NDMtMi44Mi0xLjkyMi01LjYzLTMuODA4LTguNjM2LTUuNTU5LTEuNTc0LS45MTctNC4zOTUtMS44MzctNi4wNTctMi41MTctMi4zNjgtLjk2Ni03LjU4NC0xLjkwNS04LjkzNC0zLjY0OC0yLjU2Ni0zLjMyMi0zLjAyOS01LjUzOC00Ljg0NS05LjUzMi0uNjQtMS40MDYtMS4yOTUtMy4xNTEtMi4xNS01LjMwMXpNMjkuMTMxIDIzLjc0NWE1Ljg2IDUuODYgMCAwIDEgMi4zODEgMS45MjRjLjQyNy41OTUuNjAyIDEuMTIuODM4IDEuOTk3LjUyOSAxLjk3NS0xLjc2NCA0LjA5LTEuODMgNC4xNTEtLjY2MS0xLjM0NC0uNTYxLTEuNTY2LTEuOTg2LTQuMDM0LTEuNTE5LTIuNjMtMi45NzgtMy41ODYtMi45NzgtMy42NTIgMS4wOS0uMjMzIDIuMTkxLS45NjYgMy41NzUtLjM4NnpNOTMuMjMzIDMuNjA2YzE2LjY3OCAwIDMwLjIxOCAxMy41NCAzMC4yMTggMzAuMjE4cy0xMy41NCAzMC4yMTktMzAuMjE4IDMwLjIxOS0zMC4yMTgtMTMuNTQxLTMwLjIxOC0zMC4yMTlTNzYuNTU1IDMuNjA2IDkzLjIzMyAzLjYwNnptMCAzLjc1OGMtMTQuNjA0IDAtMjYuNDYxIDExLjg1Ny0yNi40NjEgMjYuNDYxczExLjg1NyAyNi40NjEgMjYuNDYxIDI2LjQ2MSAyNi40NjEtMTEuODU3IDI2LjQ2MS0yNi40NjFTMTA3LjgzNyA3LjM2NCA5My4yMzMgNy4zNjR6JyBmaWxsPSclMjMwMDVhODUnLyUzRSUzQ3BhdGggZD0nTTQuNjI3IDE2LjEyMmguMzc2di0uODkyaC0uMjU1Yy0uNDA5IDAtLjcwMy0uMDg5LS44ODEtLjI2NXMtLjI2OC0uNDY5LS4yNjgtLjg4di0xLjYyOWMwLS4zODUtLjEyLS42ODQtLjM1OC0uODk1cy0uNTk0LS4zNC0xLjA2NS0uMzgzdi0uMTQ0Yy40NzEtLjA0My44MjUtLjE3MSAxLjA2NS0uMzg1cy4zNTgtLjUxMy4zNTgtLjg5OFY4LjE0NGMwLS40MS4wODktLjcwMi4yNjgtLjg3OVM0LjMzOSA3IDQuNzQ4IDdoLjI1NXYtLjg5MmgtLjM3NmMtLjc4NyAwLTEuMzY0LjE1My0xLjczLjQ2cy0uNTUuNzg1LS41NSAxLjQzN3YxLjM4NGMwIC40MTctLjEwMi43MDgtLjMwNC44NzNzLS41Ni4yNDktMS4wNzEuMjQ5djEuMTg2Yy41MTEuMDAzLjg2OC4wODggMS4wNzEuMjUzcy4zMDQuNDU1LjMwNC44Njh2MS40MDFjMCAuNjUxLjE4NCAxLjEzMi41NSAxLjQzOXMuOTQzLjQ2MyAxLjczLjQ2M3ptMi42NDggMGMuNzgyIDAgMS4zNTUtLjE1NCAxLjcyLS40NjNzLjU0Ny0uNzg4LjU0Ny0xLjQzOXYtMS40MDFjMC0uNDEzLjEtLjcwMi4zMDItLjg2OHMuNTU3LS4yNSAxLjA2My0uMjUzdi0xLjE4NmMtLjUwNyAwLS44NjItLjA4My0xLjA2My0uMjQ5cy0uMzAyLS40NTctLjMwMi0uODczVjguMDA1YzAtLjY1Mi0uMTgzLTEuMTMxLS41NDctMS40MzdzLS45MzktLjQ2LTEuNzItLjQ2SDYuOVY3aC4yNTVjLjQxIDAgLjcwNC4wODkuODguMjY1cy4yNjMuNDY5LjI2My44Nzl2MS42MDhjMCAuMzg2LjExOC42ODUuMzU2Ljg5OHMuNTkzLjM0MiAxLjA2My4zODV2LjE0NGMtLjQ3LjA0My0uODI1LjE3MS0xLjA2My4zODNzLS4zNTYuNTExLS4zNTYuODk1djEuNjI5YzAgLjQxMS0uMDkuNzA0LS4yNjYuODhzLS40NjkuMjY1LS44NzYuMjY1SDYuOXYuODkyaC4zNzV6JyB0cmFuc2Zvcm09J21hdHJpeCgzLjc4MTU3IDAgMCAzLjc4MTU3IDcwLjc1OTYgLTguMjU2MDQpJyBmaWxsPSclMjMwMDVhODUnIGZpbGwtcnVsZT0nbm9uemVybycvJTNFJTNDL3N2ZyUzRSIpO30ud2VsY29tZVRleHR7ZGlzcGxheTogZmxleDsgZmxleC1kaXJlY3Rpb246IGNvbHVtbjsgYWxpZ24taXRlbXM6IGNlbnRlcjsganVzdGlmeS1jb250ZW50OiBjZW50ZXI7fS53ZWxjb21lVGV4dCBwe3RleHQtYWxpZ246IGNlbnRlcjt9LndlbGNvbWVMaW5rc3twYWRkaW5nOiAzMHB4IDA7fS53ZWxjb21lU3BhY2Vye2hlaWdodDogODBweDt9LmZvb3Rlcntwb3NpdGlvbjogYWJzb2x1dGU7IGJvdHRvbTogMHB4OyBsaW5lLWhlaWdodDogMTJwdDsgZm9udC13ZWlnaHQ6IDIwMDsgZm9udC1zaXplOiAxMHB4OyBtYXJnaW46IDVweCAwO308L3N0eWxlPjwvaGVhZD48Ym9keT4gPGRpdiBjbGFzcz0id2VsY29tZVBhbmVsIj4gPGRpdiBjbGFzcz0id2VsY29tZUxvZ28iPjwvZGl2PjxkaXYgY2xhc3M9IndlbGNvbWVUZXh0Ij4gPGgyPk15U1FMIFJFU1QgU2VydmljZTwvaDI+IDxwPldlbGNvbWUgdG8gdGhlIE15U1FMIFJFU1QgU2VydmljZS48YnI+UGxlYXNlIHVzZSB0aGUgTXlTUUwgU2hlbGwgdG8gY29uZmlndXJlIHlvdXIgTXlTUUwgUkVTVCBTZXJ2aWNlLjwvcD48L2Rpdj48ZGl2IGNsYXNzPSJ3ZWxjb21lTGlua3MiPiA8YSBocmVmPSJodHRwczovL2Jsb2dzLm9yYWNsZS5jb20vbXlzcWwvcG9zdC9pbnRyb2R1Y2luZy10aGUtbXlzcWwtcmVzdC1zZXJ2aWNlIj5MZWFybiBNb3JlID48L2E+IDxhIGhyZWY9Imh0dHBzOi8vZGV2Lm15c3FsLmNvbS9kb2MvbXlzcWwtc2hlbGwtZ3VpL2VuL215c3FsLXNoZWxsLXZzY29kZS1yZXN0LXNlcnZpY2VzLmh0bWwiPkJyb3dzZSBUdXRvcmlhbHMgPjwvYT4gPGEgaHJlZj0iaHR0cHM6Ly9kZXYubXlzcWwuY29tL2RvYy9teXNxbC1zaGVsbC1ndWkvZW4iPlJlYWQgRG9jcyA+PC9hPiA8L2Rpdj48ZGl2IGNsYXNzPSJ3ZWxjb21lU3BhY2VyIj48L2Rpdj48ZGl2IGNsYXNzPSJmb290ZXIiPiBDb3B5cmlnaHQgKGMpIDIwMjMsIE9yYWNsZSBhbmQvb3IgaXRzIGFmZmlsaWF0ZXMuIDwvZGl2PjwvZGl2PjwvYm9keT48L2h0bWw+\",\n        \"favicon.ico\": \"AAABAAMAMDAQAAEABABoBgAANgAAACAgEAABAAQA6AIAAJ4GAAAQEBAAAQAEACgBAACGCQAAKAAAADAAAABgAAAAAQAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIVaCACOZAAAkWsgAJ17LwCoiUMAsJRbALykcADHs4oAz7+ZANrNsgDm3MgA7ujZAPXx6wD++/YA////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGcgAAAAAAAAAAAAAAAAAAAAAAAAAAAAK+7CAAAnYAAAAAAAAAAAAAAAAAAAAAABzYzlAAfHAAAAAAAAAAAAAAAAAAAAAAAJ5QvmAq5wAAAAAAAAAAAAAAAAAAAAAABOkAzmCuYAAAAAAAAAAAAAAAAAAAAAAACuMA7ljYAAAAAAAAAAAAAAAAAAAAAAAALZAA3q6gAAAAAAAAAAAAAAAAAAAAAAAAblAAvuwQAAAAAAAAAAAAAAAAAAAAAAAAnhAAnuUAAAAAAAAAAAAAAAAAAAAAAAAAygAATpAAAAAAAAAAAAAAAAAAAAAAAAAB6QAACiAAAAAAAAAAAAAAAAAAAAAAAAAC5wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC5gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC5wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB6AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA6QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAvAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAngAAAAAAAAAAAAAAAgAAAAAAAAAAAAAG6wAAAAAAAAAAAAAAOgAAAAAAAAAAAABewwAAAAAAAAAAAAADxwAAAAAAAAAAAATrIAAAAAAAAAAAAAAb5AAAAAAAAAAAABvCAAAAAAAAAAAAAACOsAAAAAAAAAAAAH5gAAAAAAAAACVmQgB+UAAAAAAAAAAAA9sAAAAAAAAAa+yqzqQCAAAAAAAAAAAACeUAAAAAAAAqxiAAA36RAAAAAAAAAAAAPqAAAAAAAAPJEAAAAAKrAAAAAAAAAAAArjAAABAAABuABagAqUAakAAAAAAAAAAF6AAAAKIAAHsQXoMAScIC1QAAAAAAAAA8wgAACOIAAuMAbiAABOQAawAAAAAAAAPMUAAAfoAABrAAbgAAA+QAHjAAAAAAADzlAAAAAgAACXAAjgAABOUACmAAAAAABM5QAAAAAAAACmAXyQAAALtgCXAAAAAALeQAAAAAAAAAC1A9owAAAEvQCIAAAAAAjlAAAAFlRDR3CmACrAAAAtgQCXAAAAAAywAAAmze7t7sCJAAfgAABOUADFAAAAAAvDJGne7Jq7uXBMEAbgAAA+QAPhAAAAAAbu7e7sYQAAAAALcAbTAABeMAqAAAAAAABr3LdAAAAAAAAE0wLMcAnKAGwgAAAAAAAAAAAAAAAAAAAAjDAFQAVABdUAAAAAAAAAAAAAAAAAAAAAB+YAAAACjlAAAAAAAAAAAAAAAAAAAAAAAFu4U0WcowAAAAAAAAAAAAAAAAAAAAAAAAFZvduEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoAAAAIAAAAEAAAAABAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAhVoIAIthAACQah8AmnYnAKCANwCtkFIAuKBsAMCpdwDEsYYAz7+aANfIqgDe07oA597OAPDp2gD///8AAAAAAPAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFpAAAMAAAAAAAAAAAAAAAfs0AS0AAAAAAAAAAAAAAA+OeBeQAAAAAAAAAAAAAAAuAnV5QAAAAAAAAAAAAAAAuEJ7lAAAAAAAAAAAAAAAAawB+sAAAAAAAAAAAAAAAAJgALiAAAAAAAAAAAAAAAAC1AAIAAAAAAAAAAAAAAAAAtQAAAAAAAAAAAAAAAAAAAKYAAAAAAAAAAAAAAAAAAACoAAAAAAAAAAAAAAAAAAAAigAAAAAAAAABAAAAAAAABNgAAAAAAAAAVwAAAAAAAC2AAAAAAAAAA+QAAAAAAAC6AAAAAAAAAAzAAAAAAAAF4QAAAAA6zMpCQAAAAAAADXAAAAAIxAADqhAAAAAAAG0AAAAAiQVwVhagAAAAAALVAAVgArBNMCtglQAAAAAtoABOMAlQWwAIgCsAAAAC2gAAAQAMAGoABqANAAAAHaAAAAAADAbTAALKCxAAAHwAAEqHijwAigAGoBwAAACLE2ztztxJQFsACIArAAAAPu7sYAAAA7BNMCtglQAAAAJUEAAAAACJBnBXBqAAAAAAAAAAAAAACLQAA5oQAAAAAAAAAAAAAABJzMtQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoAAAAEAAAACAAAAABAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAhVoIAIxiAACQayAAmnYhAJ59MgCnhz4Aq5BRALGVXQC3nGYAuqJvAMGqeADHs4wA0cKeANrQtgDv7uIAAAAAAAAAAAAAAAAAAAAALVBQAAAAAADHvBAAAAAAArXiAAAAAAAHQGAAAAAAAAcwAAAAAAAABVAAAAAAAAAMIAAABjAAAKQAAGg7AAACsAAqQWgAAAwRoJKQtEAAwwAAiUCzgAWTvdmEcLGAAbtgAGSSeRAAAAAAB4mTAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==\",\n        \"favicon.svg\": \"PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+CjwhRE9DVFlQRSBzdmcgUFVCTElDICItLy9XM0MvL0RURCBTVkcgMS4xLy9FTiIgImh0dHA6Ly93d3cudzMub3JnL0dyYXBoaWNzL1NWRy8xLjEvRFREL3N2ZzExLmR0ZCI+Cjxzdmcgd2lkdGg9IjEwMCUiIGhlaWdodD0iMTAwJSIgdmlld0JveD0iMCAwIDE2IDE2IiB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHhtbDpzcGFjZT0icHJlc2VydmUiIHhtbG5zOnNlcmlmPSJodHRwOi8vd3d3LnNlcmlmLmNvbS8iIHN0eWxlPSJmaWxsLXJ1bGU6ZXZlbm9kZDtjbGlwLXJ1bGU6ZXZlbm9kZDtzdHJva2UtbGluZWpvaW46cm91bmQ7c3Ryb2tlLW1pdGVybGltaXQ6MjsiPgogICAgPGcgdHJhbnNmb3JtPSJtYXRyaXgoMS4wMDE0OSwwLDAsMS4wMDE0OSwtMC4wNDkxNjYzLC0wLjA2MTg4KSI+CiAgICAgICAgPHBhdGggZD0iTTE2LjAyNSwxLjYzNkMxNi4wMjUsMC43NjcgMTUuMzIsMC4wNjIgMTQuNDUxLDAuMDYyTDEuNjI0LDAuMDYyQzAuNzU1LDAuMDYyIDAuMDQ5LDAuNzY3IDAuMDQ5LDEuNjM2TDAuMDQ5LDE0LjQ2M0MwLjA0OSwxNS4zMzIgMC43NTUsMTYuMDM4IDEuNjI0LDE2LjAzOEwxNC40NTEsMTYuMDM4QzE1LjMyLDE2LjAzOCAxNi4wMjUsMTUuMzMyIDE2LjAyNSwxNC40NjNMMTYuMDI1LDEuNjM2WiIgc3R5bGU9ImZpbGw6cmdiKDAsOTAsMTMzKTsiLz4KICAgIDwvZz4KICAgIDxnIGlkPSJtcnMiIHRyYW5zZm9ybT0ibWF0cml4KDAuMTA5OTUsLTAuMDE4MTI4NiwwLjAxODIyOTksMC4xMTA1NjQsMi45MjIsMC43NTM4NikiPgogICAgICAgIDxnIGlkPSJzYWtpbGFab29tZWQiIHRyYW5zZm9ybT0ibWF0cml4KDEuNDM1OTMsLTIuMjcwM2UtMTYsLTIuNzc1NTZlLTE3LDEuNDM1OTMsLTQwLjYyNTIsNTYuOTkzNykiPgogICAgICAgICAgICA8cGF0aCBkPSJNNTMuNzE0LC0xNS41ODlDNTIuMDYzLC0xNi4zNjEgNTAuMzM3LC0xNy4wNDMgNDguNTMsLTE3LjU5MkM0Ni4xODQsLTE4LjMwNiA0My4zNzEsLTE3LjkxMSA0MC44NTgsLTE4LjQ4OUwzOS4yNTMsLTE4LjQ4OUMzNy44NDYsLTE4LjkwMiAzNi42NywtMjAuMzk1IDM1LjUwNCwtMjEuMTY1QzMzLjA4MSwtMjIuNzc2IDMwLjY5NCwtMjMuOTA2IDI3LjgzMywtMjUuMDk2QzI2Ljc1NCwtMjUuNTQyIDIzLjg3MiwtMjYuNjEgMjIuODM2LC0yNS44MUMyMi4yMywtMjUuNjExIDIxLjk1OCwtMjUuMzUzIDIxLjc2NiwtMjQuNzQyQzIxLjE2MSwtMjMuODI4IDIxLjcxNiwtMjIuNDA5IDIyLjEyMiwtMjEuNTI0QzIzLjI3LC0xOS4wMzMgMjQuOTI2LC0xNy41MTEgMjYuNDA2LC0xNS40NDdDMjcuNzQyLC0xMy41ODggMjkuMzY5LC0xMS40NzEgMzAuMzMsLTkuMzc0QzMyLjM0MywtNC45OTggMzMuMjM2LC0wLjEzMyAzNS4xNDgsNC4xOTlDMzUuODgzLDUuODYzIDM2Ljk0Myw3Ljc2MyAzOC4wMDQsOS4xOTlDMzguODYxLDEwLjM3IDQwLjM5NCwxMS4yNDcgNDAuODU4LDEyLjc3NkM0MS44MywxNC4zMDEgMzkuNDI4LDE5LjUxOCAzOC44OTUsMjEuMTc0QzM2LjgzOSwyNy41NjQgMzcuMjc0LDM2LjUxMiAzOS42MDksNDIuMDcxQzQwLjUzMyw0NC4yNyA0MS40MDcsNDYuODMxIDQzLjg5Miw0Ny40M0M0NC4wNzUsNDcuMjg4IDQzLjkzNSw0Ny4zNjUgNDQuMjQ4LDQ3LjI1MUM0NC43NzgsNDIuOTczIDQ0Ljk2MiwzOC44NDkgNDYuMzksMzUuNDY0QzQ3LjI4MywzMy4zNDMgNDguOTgzLDMxLjg5NiA1MC4xMzgsMzAuMTAxQzUwLjk4MywzMC41OTUgNTAuOTc5LDMyLjAxOCA1MS4zODUsMzIuOTZDNTIuNDQxLDM1LjQwNyA1My41MjcsMzguMDYzIDU0Ljc3Niw0MC40NjRDNTcuMzk1LDQ1LjQ5NyA2Mi43MzQsNTEuNjk4IDYzLjI0Nyw1Mi4zODJDNjUuMjA5LDU0Ljk5NiA2MS43MjUsNTIuOTY3IDU4Ljk2OSw1MC45NjdDNTYuODA3LDQ5LjM5OSA1NS44NTksNDguMzgyIDU0LjE2NCw0Ni4yNTVDNTIuNjcyLDQ0LjM4MyA1MS41NjQsNDEuNzEyIDUwLjQ5NCwzOS41NjdMNTAuNDk0LDM5LjM5MkM1MC4wNDYsMzkuOTkxIDUwLjE4Niw0MC42NDQgNDkuOTU4LDQxLjUzMkM0OC45NDksNDUuNDY1IDQ5LjczNiw0OS45MjMgNDYuMjEyLDUxLjM2M0M0Mi4xOCw1My4wMDUgMzkuMjQ5LDQ4LjcxNiAzOC4wMDQsNDYuNzE3QzMzLjk0Nyw0MC4xOTkgMzIuODk1LDI5LjI2MSAzNS42ODUsMjAuNDZDMzYuMzAyLDE4LjUwMiAzNi4zNjQsMTYuMTA4IDM3LjQ2OCwxNC41NjJDMzcuMjg5LDEzLjE3NSAzNi4xNjIsMTIuNzggMzUuNTA0LDExLjg4M0MzNC40MzMsMTAuNDE4IDMzLjQ5OSw4LjY5MyAzMi42NSw3LjA1N0MzMC45NzMsMy44MjQgMjkuODQ1LDAuMDE4IDI4LjU0NywtMy40ODFDMjguMDE5LC00LjkgMjcuOTEzLC02LjI0NyAyNy4yOTgsLTcuNTkyQzI2LjM2LC05LjYzMSAyNC42ODIsLTExLjY2NyAyMy4zNzEsLTEzLjQ4NkMyMS41MDQsLTE2LjA3MSAxNi4yODMsLTIxLjA2IDE4LjM3NiwtMjYuMTdDMjEuNjkxLC0zNC4yNjUgMzMuMTcxLC0yOC4xMDcgMzcuNjQ3LC0yNS4yNzdDMzguNzcsLTI0LjU2MyA0MC4wMTcsLTIzLjA5NSA0MS4yMTUsLTIyLjU5N0M0My4xNzcsLTIyLjQ3NCA0NC41NDQsLTIyLjcwMSA0Ny4xMDMsLTIyLjIzN0M1MC4wNDUsLTIxLjcwNSA1Mi44MTEsLTIxLjA0OSA1NS4yNjYsLTE5Ljk1OEw1My43MTQsLTE1LjU4OVpNODcuNjYxLDEwLjY4NEM4OS4yMDYsMTMuNTg5IDkwLjA5NCwxOC45NzkgOTAuMTIsMjEuMDFDOTAuMTQ2LDIzLjEyIDg5LjUxNywyMy4yMjcgODguODE1LDIyLjI5Qzg2LjUwNCwxOS4yMDYgODUuMTQzLDE2LjMzNiA4NC4yMTgsMTQuNTYyQzgzLjg5LDEzLjkzMyA4My41NTQsMTMuMzA5IDgzLjIwOSwxMi42OTJMODcuNjYxLDEwLjY4NFpNNDQuMDcsLTEwLjgwNkM0NC45NzEsLTEwLjYwOCA0NS43LC05Ljc1OCA0Ni4yMTIsLTkuMDE5QzQ2LjU5NSwtOC40NjUgNDYuNzQ2LC04LjA0OSA0Ni44NDcsLTcuMDY4QzQ3LjA0NCwtNS4xNzcgNDYuNjAzLC00LjI2MSA0NS40OTgsLTMuNDgxQzQ1LjQzOCwtMy40MjQgNDUuMzc5LC0zLjM2MyA0NS4zMiwtMy4zMDZDNDQuNzI0LC00LjU1NCA0NC4yNDksLTUuODcgNDMuNTM1LC03LjA1NEM0Mi4yNTEsLTkuMTgzIDQyLjA4NywtOC44MTYgNDEuMDM2LC0xMC4yNzFDNDEuMDAyLC0xMC4zMiA0MC45MTgsLTEwLjI3MSA0MC44NTgsLTEwLjI3MUw0MC44NTgsLTEwLjQ0N0M0MS44MzgsLTEwLjY2MyA0Mi43NjIsLTEwLjgzIDQ0LjA3LC0xMC44MDZaIiBzdHlsZT0iZmlsbDp3aGl0ZTsiLz4KICAgICAgICA8L2c+CiAgICAgICAgPGcgdHJhbnNmb3JtPSJtYXRyaXgoMC4wNTYyNjgsMC4wMDkyMjU5OCwtMC4wMDkyNzc1NCwwLjA1NTk1NTYsNDUuMDIzOSw5LjQ5MDExKSI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik01MTEuNzE1LDEuNTk1Qzc5My45NzYsMS41OTUgMTAyMy4xMywyMzAuNzU1IDEwMjMuMTMsNTEzLjAxNkMxMDIzLjEzLDc5NS4yNzcgNzkzLjk3NiwxMDI0LjQ0IDUxMS43MTUsMTAyNC40NEMyMjkuNDU0LDEwMjQuNDQgMC4yOTQsNzk1LjI3NyAwLjI5NCw1MTMuMDE2QzAuMjk0LDIzMC43NTUgMjI5LjQ1NCwxLjU5NSA1MTEuNzE1LDEuNTk1Wk01MTEuNzE1LDY1LjE5QzI2NC41NTMsNjUuMTkgNjMuODg5LDI2NS44NTQgNjMuODg5LDUxMy4wMTZDNjMuODg5LDc2MC4xNzggMjY0LjU1Myw5NjAuODQyIDUxMS43MTUsOTYwLjg0MkM3NTguODc3LDk2MC44NDIgOTU5LjU0MSw3NjAuMTc4IDk1OS41NDEsNTEzLjAxNkM5NTkuNTQxLDI2NS44NTQgNzU4Ljg3Nyw2NS4xOSA1MTEuNzE1LDY1LjE5WiIgc3R5bGU9ImZpbGw6d2hpdGU7Ii8+CiAgICAgICAgPC9nPgogICAgICAgIDxnIHRyYW5zZm9ybT0ibWF0cml4KDMuNjAxMTUsMC41OTA0NjMsLTAuNTkzNzYyLDMuNTgxMTYsNTQuMjYzNSwtMC40NDE5ODYpIj4KICAgICAgICAgICAgPGcgdHJhbnNmb3JtPSJtYXRyaXgoMS4xODU3OCwwLDAsMS4wNDIyNSwtMC43ODEwMDUsLTAuNDY2NTAzKSI+CiAgICAgICAgICAgICAgICA8cGF0aCBkPSJNNC41NjEsMTUuOTE2TDQuODc4LDE1LjkxNkw0Ljg3OCwxNS4wNkw0LjY2MywxNS4wNkM0LjMxOCwxNS4wNiA0LjA3LDE0Ljk3NSAzLjkyLDE0LjgwNkMzLjc2OSwxNC42MzcgMy42OTQsMTQuMzU2IDMuNjk0LDEzLjk2MkwzLjY5NCwxMi4zOTlDMy42OTQsMTIuMDMgMy41OTMsMTEuNzQzIDMuMzkyLDExLjU0QzMuMTksMTEuMzM3IDIuODkxLDExLjIxNCAyLjQ5NCwxMS4xNzNMMi40OTQsMTEuMDM1QzIuODkxLDEwLjk5NCAzLjE5LDEwLjg3MSAzLjM5MiwxMC42NjZDMy41OTMsMTAuNDYxIDMuNjk0LDEwLjE3NCAzLjY5NCw5LjgwNEwzLjY5NCw4LjI2MUMzLjY5NCw3Ljg2OCAzLjc2OSw3LjU4NyAzLjkyLDcuNDE4QzQuMDcsNy4yNDkgNC4zMTgsNy4xNjQgNC42NjMsNy4xNjRMNC44NzgsNy4xNjRMNC44NzgsNi4zMDhMNC41NjEsNi4zMDhDMy44OTcsNi4zMDggMy40MTEsNi40NTUgMy4xMDIsNi43NDlDMi43OTMsNy4wNDMgMi42MzgsNy41MDIgMi42MzgsOC4xMjhMMi42MzgsOS40NTZDMi42MzgsOS44NTYgMi41NTIsMTAuMTM1IDIuMzgyLDEwLjI5NEMyLjIxMSwxMC40NTMgMS45MSwxMC41MzMgMS40NzksMTAuNTMzTDEuNDc5LDExLjY3MUMxLjkxLDExLjY3NCAyLjIxMSwxMS43NTUgMi4zODIsMTEuOTE0QzIuNTUyLDEyLjA3MyAyLjYzOCwxMi4zNTEgMi42MzgsMTIuNzQ3TDIuNjM4LDE0LjA5MUMyLjYzOCwxNC43MTYgMi43OTMsMTUuMTc3IDMuMTAyLDE1LjQ3MkMzLjQxMSwxNS43NjggMy44OTcsMTUuOTE2IDQuNTYxLDE1LjkxNloiIHN0eWxlPSJmaWxsOndoaXRlO2ZpbGwtcnVsZTpub256ZXJvOyIvPgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxnIHRyYW5zZm9ybT0ibWF0cml4KDEuMTc5MDMsMCwwLDEuMDQyMjUsLTEuMzcxOTYsLTAuNDY2NTAzKSI+CiAgICAgICAgICAgICAgICA8cGF0aCBkPSJNNy4zMzQsMTUuOTE2QzcuOTk3LDE1LjkxNiA4LjQ4MywxNS43NjggOC43OTMsMTUuNDcyQzkuMTAyLDE1LjE3NyA5LjI1NywxNC43MTYgOS4yNTcsMTQuMDkxTDkuMjU3LDEyLjc0N0M5LjI1NywxMi4zNTEgOS4zNDIsMTIuMDczIDkuNTEzLDExLjkxNEM5LjY4NCwxMS43NTUgOS45ODUsMTEuNjc0IDEwLjQxNSwxMS42NzFMMTAuNDE1LDEwLjUzM0M5Ljk4NSwxMC41MzMgOS42ODQsMTAuNDUzIDkuNTEzLDEwLjI5NEM5LjM0MiwxMC4xMzUgOS4yNTcsOS44NTYgOS4yNTcsOS40NTZMOS4yNTcsOC4xMjhDOS4yNTcsNy41MDIgOS4xMDIsNy4wNDMgOC43OTMsNi43NDlDOC40ODMsNi40NTUgNy45OTcsNi4zMDggNy4zMzQsNi4zMDhMNy4wMTYsNi4zMDhMNy4wMTYsNy4xNjRMNy4yMzIsNy4xNjRDNy41OCw3LjE2NCA3LjgyOSw3LjI0OSA3Ljk3OCw3LjQxOEM4LjEyNiw3LjU4NyA4LjIwMSw3Ljg2OCA4LjIwMSw4LjI2MUw4LjIwMSw5LjgwNEM4LjIwMSwxMC4xNzQgOC4zMDEsMTAuNDYxIDguNTAzLDEwLjY2NkM4LjcwNSwxMC44NzEgOS4wMDYsMTAuOTk0IDkuNDA1LDExLjAzNUw5LjQwNSwxMS4xNzNDOS4wMDYsMTEuMjE0IDguNzA1LDExLjMzNyA4LjUwMywxMS41NEM4LjMwMSwxMS43NDMgOC4yMDEsMTIuMDMgOC4yMDEsMTIuMzk5TDguMjAxLDEzLjk2MkM4LjIwMSwxNC4zNTYgOC4xMjUsMTQuNjM3IDcuOTc1LDE0LjgwNkM3LjgyNSwxNC45NzUgNy41NzcsMTUuMDYgNy4yMzIsMTUuMDZMNy4wMTYsMTUuMDZMNy4wMTYsMTUuOTE2TDcuMzM0LDE1LjkxNloiIHN0eWxlPSJmaWxsOndoaXRlO2ZpbGwtcnVsZTpub256ZXJvOyIvPgogICAgICAgICAgICA8L2c+CiAgICAgICAgPC9nPgogICAgPC9nPgo8L3N2Zz4K\"\n    },\n    \"directoryIndexDirective\": [\n        \"index.html\"\n    ]\n}');

COMMIT;


-- -----------------------------------------------------
-- Data for table `mysql_rest_service_metadata`.`mrs_role`
-- -----------------------------------------------------
START TRANSACTION;
USE `mysql_rest_service_metadata`;
INSERT INTO `mysql_rest_service_metadata`.`mrs_role` (`id`, `derived_from_role_id`, `specific_to_service_id`, `caption`, `description`, `options`) VALUES (0x31, NULL, NULL, 'Full Access', 'Full access to all db_objects', NULL);

COMMIT;


-- -----------------------------------------------------
-- Data for table `mysql_rest_service_metadata`.`mrs_user_hierarchy_type`
-- -----------------------------------------------------
START TRANSACTION;
USE `mysql_rest_service_metadata`;
INSERT INTO `mysql_rest_service_metadata`.`mrs_user_hierarchy_type` (`id`, `caption`, `description`, `specific_to_service_id`, `options`) VALUES (0x31, 'Direct Report', 'And employee directly reporting to the user', NULL, NULL);
INSERT INTO `mysql_rest_service_metadata`.`mrs_user_hierarchy_type` (`id`, `caption`, `description`, `specific_to_service_id`, `options`) VALUES (0x32, 'Dotted Line Report', 'And employee reporting to the user via a dotted line relationship', NULL, NULL);

COMMIT;


-- -----------------------------------------------------
-- Data for table `mysql_rest_service_metadata`.`mrs_privilege`
-- -----------------------------------------------------
START TRANSACTION;
USE `mysql_rest_service_metadata`;
INSERT INTO `mysql_rest_service_metadata`.`mrs_privilege` (`id`, `role_id`, `crud_operations`, `service_id`, `db_schema_id`, `db_object_id`, `options`) VALUES (0x31, 0x31, 'CREATE,READ,UPDATE,DELETE', NULL, NULL, NULL, NULL);

COMMIT;

-- -----------------------------------------------------
-- Additional SQL

-- Ensure only one row in `mysql_rest_service_metadata`.`config`
ALTER TABLE `mysql_rest_service_metadata`.`config`
	ADD CONSTRAINT Config_OnlyOneRow CHECK (id = 1);

-- Ensure there is a default for service.name taken from url_context_root
ALTER TABLE `mysql_rest_service_metadata`.`service`
    CHANGE COLUMN name name VARCHAR(255) NOT NULL DEFAULT (REGEXP_REPLACE(url_context_root, '[^0-9a-zA-Z ]', ''));

-- Ensure page size is within 16K limit
ALTER TABLE `mysql_rest_service_metadata`.`db_schema`
	ADD CONSTRAINT db_schema_max_page_size CHECK (items_per_page IS NULL OR items_per_page < 16384);
ALTER TABLE `mysql_rest_service_metadata`.`db_object`
	ADD CONSTRAINT db_object_max_page_size CHECK (items_per_page IS NULL OR items_per_page < 16384);

DELIMITER $$

CREATE FUNCTION `mysql_rest_service_metadata`.`get_sequence_id`() RETURNS BINARY(16) SQL SECURITY INVOKER NOT DETERMINISTIC NO SQL
RETURN UUID_TO_BIN(UUID(), 1)$$

CREATE EVENT `mysql_rest_service_metadata`.`delete_old_audit_log_entries` ON SCHEDULE EVERY 1 DAY DISABLE DO
DELETE FROM `mysql_rest_service_metadata`.`audit_log` WHERE changed_at < TIMESTAMP(DATE_SUB(NOW(), INTERVAL 14 DAY))$$


CREATE FUNCTION `mysql_rest_service_metadata`.`valid_request_path`(path VARCHAR(255))
RETURNS TINYINT(1) NOT DETERMINISTIC READS SQL DATA
BEGIN
    SET @valid := (SELECT COUNT(*) = 0 AS valid FROM
        (SELECT CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name,
            se.url_context_root) as full_request_path
        FROM `mysql_rest_service_metadata`.service se
            LEFT JOIN `mysql_rest_service_metadata`.url_host h
                ON se.url_host_id = h.id
        WHERE CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root) = path
            AND se.enabled = TRUE
        UNION
        SELECT CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root,
            sc.request_path) as full_request_path
        FROM `mysql_rest_service_metadata`.db_schema sc
            LEFT OUTER JOIN `mysql_rest_service_metadata`.service se
                ON se.id = sc.service_id
            LEFT JOIN `mysql_rest_service_metadata`.url_host h
                ON se.url_host_id = h.id
        WHERE CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root,
                sc.request_path) = path
            AND se.enabled = TRUE
        UNION
        SELECT CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root,
            sc.request_path, o.request_path) as full_request_path
        FROM `mysql_rest_service_metadata`.db_object o
            LEFT OUTER JOIN `mysql_rest_service_metadata`.db_schema sc
                ON sc.id = o.db_schema_id
            LEFT OUTER JOIN `mysql_rest_service_metadata`.service se
                ON se.id = sc.service_id
            LEFT JOIN `mysql_rest_service_metadata`.url_host h
                ON se.url_host_id = h.id
        WHERE CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root,
                sc.request_path, o.request_path) = path
            AND se.enabled = TRUE
        UNION
        SELECT CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root,
            co.request_path) as full_request_path
        FROM `mysql_rest_service_metadata`.content_set co
            LEFT OUTER JOIN `mysql_rest_service_metadata`.service se
                ON se.id = co.service_id
            LEFT JOIN `mysql_rest_service_metadata`.url_host h
                ON se.url_host_id = h.id
        WHERE CONCAT(COALESCE(se.in_development->>'$.developers', ''), h.name, se.url_context_root,
                co.request_path) = path
            AND se.enabled = TRUE) AS p);

    RETURN @valid;
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`router_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `router` FOR EACH ROW
BEGIN
    INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
        table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
    VALUES (
        "router",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "options", NEW.options),
        NULL,
        UNHEX(LPAD(CONV(NEW.id, 10, 16), 32, '0')),
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`router_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `router` FOR EACH ROW
BEGIN
    IF (COALESCE(OLD.options, '') <> COALESCE(NEW.options, '')) THEN
        INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
            table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
        VALUES (
            "router",
            "UPDATE",
            JSON_OBJECT(
                "id", OLD.id,
                "options", OLD.options),
            JSON_OBJECT(
                "id", NEW.id,
                "options", NEW.options),
            UNHEX(LPAD(CONV(OLD.id, 10, 16), 32, '0')),
            UNHEX(LPAD(CONV(NEW.id, 10, 16), 32, '0')),
            CURRENT_USER(),
            CURRENT_TIMESTAMP
        );
    END IF;
END$$

DELIMITER ;

-- Ensure that for STORED PROCEDURE parameters at least one of the 'in' and 'out' flag is set to true
ALTER TABLE `mysql_rest_service_metadata`.`object_field`
  ADD CONSTRAINT param_mode_not_false CHECK (
    (db_column->"$.in" IS NULL AND db_column->"$.out" IS NULL) OR
    (db_column->"$.in" + db_column->"$.out" >= 1));

-- Ensure the service.in_development->>$.developers is a list that only holds unique strings
ALTER TABLE `mysql_rest_service_metadata`.`service`
  ADD CONSTRAINT in_development_developers_check CHECK(
    JSON_SCHEMA_VALID('{
    "id": "https://dev.mysql.com/mrs/service/in_development",
    "type": "object",
    "properties": {
        "developers": {
            "type": "array",
            "items": {
                "type": "string"
            },
            "minItems": 1,
            "uniqueItems": true
        }
    },
    "required": [ "developers" ]
    }', s.in_development)
);

-- -----------------------------------------------------
-- Create audit_log triggers
--

DELIMITER $$
CREATE TRIGGER `mysql_rest_service_metadata`.`db_schema_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `db_schema` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "db_schema",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "service_id", NEW.service_id,
            "name", NEW.name,
            "schema_type", NEW.schema_type,
            "request_path", NEW.request_path,
            "requires_auth", NEW.requires_auth,
            "enabled", NEW.enabled,
            "internal", NEW.internal,
            "items_per_page", NEW.items_per_page,
            "comments", NEW.comments,
            "options", NEW.options,
            "metadata", NEW.metadata),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`db_schema_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `db_schema` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "db_schema",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "service_id", OLD.service_id,
            "name", OLD.name,
            "schema_type", OLD.schema_type,
            "request_path", OLD.request_path,
            "requires_auth", OLD.requires_auth,
            "enabled", OLD.enabled,
            "internal", OLD.internal,
            "items_per_page", OLD.items_per_page,
            "comments", OLD.comments,
            "options", OLD.options,
            "metadata", OLD.metadata),
        JSON_OBJECT(
            "id", NEW.id,
            "service_id", NEW.service_id,
            "name", NEW.name,
            "schema_type", NEW.schema_type,
            "request_path", NEW.request_path,
            "requires_auth", NEW.requires_auth,
            "enabled", NEW.enabled,
            "internal", NEW.internal,
            "items_per_page", NEW.items_per_page,
            "comments", NEW.comments,
            "options", NEW.options,
            "metadata", NEW.metadata),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`db_schema_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `db_schema` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "db_schema",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "service_id", OLD.service_id,
            "name", OLD.name,
            "schema_type", OLD.schema_type,
            "request_path", OLD.request_path,
            "requires_auth", OLD.requires_auth,
            "enabled", OLD.enabled,
            "internal", OLD.internal,
            "items_per_page", OLD.items_per_page,
            "comments", OLD.comments,
            "options", OLD.options,
            "metadata", OLD.metadata),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`service_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `service` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "service",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "parent_id", NEW.parent_id,
            "url_host_id", NEW.url_host_id,
            "url_context_root", NEW.url_context_root,
            "url_protocol", NEW.url_protocol,
            "name", NEW.name,
            "enabled", NEW.enabled,
            "published", NEW.published,
            "in_development", NEW.in_development,
            "comments", NEW.comments,
            "options", NEW.options,
            "auth_path", NEW.auth_path,
            "auth_completed_url", NEW.auth_completed_url,
            "auth_completed_url_validation", NEW.auth_completed_url_validation,
            "enable_sql_endpoint", NEW.enable_sql_endpoint,
            "custom_metadata_schema", NEW.custom_metadata_schema,
            "metadata", NEW.metadata),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`service_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `service` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "service",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "parent_id", OLD.parent_id,
            "url_host_id", OLD.url_host_id,
            "url_context_root", OLD.url_context_root,
            "url_protocol", OLD.url_protocol,
            "name", OLD.name,
            "enabled", OLD.enabled,
            "published", OLD.published,
            "in_development", OLD.in_development,
            "comments", OLD.comments,
            "options", OLD.options,
            "auth_path", OLD.auth_path,
            "auth_completed_url", OLD.auth_completed_url,
            "auth_completed_url_validation", OLD.auth_completed_url_validation,
            "enable_sql_endpoint", OLD.enable_sql_endpoint,
            "custom_metadata_schema", OLD.custom_metadata_schema,
            "metadata", OLD.metadata),
        JSON_OBJECT(
            "id", NEW.id,
            "parent_id", NEW.parent_id,
            "url_host_id", NEW.url_host_id,
            "url_context_root", NEW.url_context_root,
            "url_protocol", NEW.url_protocol,
            "name", NEW.name,
            "enabled", NEW.enabled,
            "published", NEW.published,
            "in_development", NEW.in_development,
            "comments", NEW.comments,
            "options", NEW.options,
            "auth_path", NEW.auth_path,
            "auth_completed_url", NEW.auth_completed_url,
            "auth_completed_url_validation", NEW.auth_completed_url_validation,
            "enable_sql_endpoint", NEW.enable_sql_endpoint,
            "custom_metadata_schema", NEW.custom_metadata_schema,
            "metadata", NEW.metadata),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`service_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `service` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "service",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "parent_id", OLD.parent_id,
            "url_host_id", OLD.url_host_id,
            "url_context_root", OLD.url_context_root,
            "url_protocol", OLD.url_protocol,
            "name", OLD.name,
            "enabled", OLD.enabled,
            "published", OLD.published,
            "in_development", OLD.in_development,
            "comments", OLD.comments,
            "options", OLD.options,
            "auth_path", OLD.auth_path,
            "auth_completed_url", OLD.auth_completed_url,
            "auth_completed_url_validation", OLD.auth_completed_url_validation,
            "enable_sql_endpoint", OLD.enable_sql_endpoint,
            "custom_metadata_schema", OLD.custom_metadata_schema,
            "metadata", OLD.metadata),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`db_object_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `db_object` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "db_object",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "db_schema_id", NEW.db_schema_id,
            "name", NEW.name,
            "request_path", NEW.request_path,
            "enabled", NEW.enabled,
            "internal", NEW.internal,
            "object_type", NEW.object_type,
            "crud_operations", NEW.crud_operations,
            "format", NEW.format,
            "items_per_page", NEW.items_per_page,
            "media_type", NEW.media_type,
            "auto_detect_media_type", NEW.auto_detect_media_type,
            "requires_auth", NEW.requires_auth,
            "auth_stored_procedure", NEW.auth_stored_procedure,
            "options", NEW.options,
            "details", NEW.details,
            "comments", NEW.comments,
            "metadata", NEW.metadata),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`db_object_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `db_object` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "db_object",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "db_schema_id", OLD.db_schema_id,
            "name", OLD.name,
            "request_path", OLD.request_path,
            "enabled", OLD.enabled,
            "internal", OLD.internal,
            "object_type", OLD.object_type,
            "crud_operations", OLD.crud_operations,
            "format", OLD.format,
            "items_per_page", OLD.items_per_page,
            "media_type", OLD.media_type,
            "auto_detect_media_type", OLD.auto_detect_media_type,
            "requires_auth", OLD.requires_auth,
            "auth_stored_procedure", OLD.auth_stored_procedure,
            "options", OLD.options,
            "details", OLD.details,
            "comments", OLD.comments,
            "metadata", OLD.metadata),
        JSON_OBJECT(
            "id", NEW.id,
            "db_schema_id", NEW.db_schema_id,
            "name", NEW.name,
            "request_path", NEW.request_path,
            "enabled", NEW.enabled,
            "internal", NEW.internal,
            "object_type", NEW.object_type,
            "crud_operations", NEW.crud_operations,
            "format", NEW.format,
            "items_per_page", NEW.items_per_page,
            "media_type", NEW.media_type,
            "auto_detect_media_type", NEW.auto_detect_media_type,
            "requires_auth", NEW.requires_auth,
            "auth_stored_procedure", NEW.auth_stored_procedure,
            "options", NEW.options,
            "details", NEW.details,
            "comments", NEW.comments,
            "metadata", NEW.metadata),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`db_object_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `db_object` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "db_object",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "db_schema_id", OLD.db_schema_id,
            "name", OLD.name,
            "request_path", OLD.request_path,
            "enabled", OLD.enabled,
            "internal", OLD.internal,
            "object_type", OLD.object_type,
            "crud_operations", OLD.crud_operations,
            "format", OLD.format,
            "items_per_page", OLD.items_per_page,
            "media_type", OLD.media_type,
            "auto_detect_media_type", OLD.auto_detect_media_type,
            "requires_auth", OLD.requires_auth,
            "auth_stored_procedure", OLD.auth_stored_procedure,
            "options", OLD.options,
            "details", OLD.details,
            "comments", OLD.comments,
            "metadata", OLD.metadata),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `mrs_user` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "auth_app_id", NEW.auth_app_id,
            "name", NEW.name,
            "email", NEW.email,
            "vendor_user_id", NEW.vendor_user_id,
            "login_permitted", NEW.login_permitted,
            "mapped_user_id", NEW.mapped_user_id,
            "app_options", NEW.app_options,
            "options", NEW.options),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `mrs_user` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "auth_app_id", OLD.auth_app_id,
            "name", OLD.name,
            "email", OLD.email,
            "vendor_user_id", OLD.vendor_user_id,
            "login_permitted", OLD.login_permitted,
            "mapped_user_id", OLD.mapped_user_id,
            "app_options", OLD.app_options,
            "options", OLD.options),
        JSON_OBJECT(
            "id", NEW.id,
            "auth_app_id", NEW.auth_app_id,
            "name", NEW.name,
            "email", NEW.email,
            "vendor_user_id", NEW.vendor_user_id,
            "login_permitted", NEW.login_permitted,
            "mapped_user_id", NEW.mapped_user_id,
            "app_options", NEW.app_options,
            "options", NEW.options),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `mrs_user` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "auth_app_id", OLD.auth_app_id,
            "name", OLD.name,
            "email", OLD.email,
            "vendor_user_id", OLD.vendor_user_id,
            "login_permitted", OLD.login_permitted,
            "mapped_user_id", OLD.mapped_user_id,
            "app_options", OLD.app_options,
            "options", OLD.options),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`auth_vendor_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `auth_vendor` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "auth_vendor",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "name", NEW.name,
            "validation_url", NEW.validation_url,
            "enabled", NEW.enabled,
            "comments", NEW.comments,
            "options", NEW.options),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`auth_vendor_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `auth_vendor` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "auth_vendor",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "name", OLD.name,
            "validation_url", OLD.validation_url,
            "enabled", OLD.enabled,
            "comments", OLD.comments,
            "options", OLD.options),
        JSON_OBJECT(
            "id", NEW.id,
            "name", NEW.name,
            "validation_url", NEW.validation_url,
            "enabled", NEW.enabled,
            "comments", NEW.comments,
            "options", NEW.options),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`auth_vendor_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `auth_vendor` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "auth_vendor",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "name", OLD.name,
            "validation_url", OLD.validation_url,
            "enabled", OLD.enabled,
            "comments", OLD.comments,
            "options", OLD.options),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`auth_app_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `auth_app` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "auth_app",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "auth_vendor_id", NEW.auth_vendor_id,
            "name", NEW.name,
            "description", NEW.description,
            "url", NEW.url,
            "url_direct_auth", NEW.url_direct_auth,
            "access_token", NEW.access_token,
            "app_id", NEW.app_id,
            "enabled", NEW.enabled,
            "limit_to_registered_users", NEW.limit_to_registered_users,
            "default_role_id", NEW.default_role_id,
            "options", NEW.options),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`auth_app_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `auth_app` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "auth_app",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "auth_vendor_id", OLD.auth_vendor_id,
            "name", OLD.name,
            "description", OLD.description,
            "url", OLD.url,
            "url_direct_auth", OLD.url_direct_auth,
            "access_token", OLD.access_token,
            "app_id", OLD.app_id,
            "enabled", OLD.enabled,
            "limit_to_registered_users", OLD.limit_to_registered_users,
            "default_role_id", OLD.default_role_id,
            "options", OLD.options),
        JSON_OBJECT(
            "id", NEW.id,
            "auth_vendor_id", NEW.auth_vendor_id,
            "name", NEW.name,
            "description", NEW.description,
            "url", NEW.url,
            "url_direct_auth", NEW.url_direct_auth,
            "access_token", NEW.access_token,
            "app_id", NEW.app_id,
            "enabled", NEW.enabled,
            "limit_to_registered_users", NEW.limit_to_registered_users,
            "default_role_id", NEW.default_role_id,
            "options", NEW.options),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`auth_app_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `auth_app` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "auth_app",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "auth_vendor_id", OLD.auth_vendor_id,
            "name", OLD.name,
            "description", OLD.description,
            "url", OLD.url,
            "url_direct_auth", OLD.url_direct_auth,
            "access_token", OLD.access_token,
            "app_id", OLD.app_id,
            "enabled", OLD.enabled,
            "limit_to_registered_users", OLD.limit_to_registered_users,
            "default_role_id", OLD.default_role_id,
            "options", OLD.options),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`config_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `config` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "config",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "service_enabled", NEW.service_enabled,
            "data", NEW.data),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`config_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `config` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "config",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "service_enabled", OLD.service_enabled,
            "data", OLD.data),
        JSON_OBJECT(
            "id", NEW.id,
            "service_enabled", NEW.service_enabled,
            "data", NEW.data),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`config_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `config` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "config",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "service_enabled", OLD.service_enabled,
            "data", OLD.data),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`redirect_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `redirect` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "redirect",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "pattern", NEW.pattern,
            "target", NEW.target),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`redirect_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `redirect` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "redirect",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "pattern", OLD.pattern,
            "target", OLD.target),
        JSON_OBJECT(
            "id", NEW.id,
            "pattern", NEW.pattern,
            "target", NEW.target),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`redirect_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `redirect` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "redirect",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "pattern", OLD.pattern,
            "target", OLD.target),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`url_host_alias_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `url_host_alias` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "url_host_alias",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "url_host_id", NEW.url_host_id,
            "alias", NEW.alias),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`url_host_alias_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `url_host_alias` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "url_host_alias",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "url_host_id", OLD.url_host_id,
            "alias", OLD.alias),
        JSON_OBJECT(
            "id", NEW.id,
            "url_host_id", NEW.url_host_id,
            "alias", NEW.alias),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`url_host_alias_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `url_host_alias` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "url_host_alias",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "url_host_id", OLD.url_host_id,
            "alias", OLD.alias),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`url_host_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `url_host` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "url_host",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "name", NEW.name,
            "comments", NEW.comments),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`url_host_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `url_host` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "url_host",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "name", OLD.name,
            "comments", OLD.comments),
        JSON_OBJECT(
            "id", NEW.id,
            "name", NEW.name,
            "comments", NEW.comments),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`url_host_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `url_host` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "url_host",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "name", OLD.name,
            "comments", OLD.comments),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`content_file_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `content_file` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "content_file",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "content_set_id", NEW.content_set_id,
            "request_path", NEW.request_path,
            "requires_auth", NEW.requires_auth,
            "enabled", NEW.enabled,
            "size", NEW.size,
            "options", NEW.options),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`content_file_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `content_file` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "content_file",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "content_set_id", OLD.content_set_id,
            "request_path", OLD.request_path,
            "requires_auth", OLD.requires_auth,
            "enabled", OLD.enabled,
            "size", OLD.size,
            "options", OLD.options),
        JSON_OBJECT(
            "id", NEW.id,
            "content_set_id", NEW.content_set_id,
            "request_path", NEW.request_path,
            "requires_auth", NEW.requires_auth,
            "enabled", NEW.enabled,
            "size", NEW.size,
            "options", NEW.options),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`content_file_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `content_file` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "content_file",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "content_set_id", OLD.content_set_id,
            "request_path", OLD.request_path,
            "requires_auth", OLD.requires_auth,
            "enabled", OLD.enabled,
            "size", OLD.size,
            "options", OLD.options),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`content_set_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `content_set` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "content_set",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "service_id", NEW.service_id,
            "content_type", NEW.content_type,
            "request_path", NEW.request_path,
            "requires_auth", NEW.requires_auth,
            "enabled", NEW.enabled,
            "internal", NEW.internal,
            "comments", NEW.comments,
            "options", NEW.options),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`content_set_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `content_set` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "content_set",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "service_id", OLD.service_id,
            "content_type", OLD.content_type,
            "request_path", OLD.request_path,
            "requires_auth", OLD.requires_auth,
            "enabled", OLD.enabled,
            "internal", OLD.internal,
            "comments", OLD.comments,
            "options", OLD.options),
        JSON_OBJECT(
            "id", NEW.id,
            "service_id", NEW.service_id,
            "content_type", NEW.content_type,
            "request_path", NEW.request_path,
            "requires_auth", NEW.requires_auth,
            "enabled", NEW.enabled,
            "internal", NEW.internal,
            "comments", NEW.comments,
            "options", NEW.options),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`content_set_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `content_set` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "content_set",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "service_id", OLD.service_id,
            "content_type", OLD.content_type,
            "request_path", OLD.request_path,
            "requires_auth", OLD.requires_auth,
            "enabled", OLD.enabled,
            "internal", OLD.internal,
            "comments", OLD.comments,
            "options", OLD.options),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_role_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `mrs_role` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_role",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "derived_from_role_id", NEW.derived_from_role_id,
            "specific_to_service_id", NEW.specific_to_service_id,
            "caption", NEW.caption,
            "description", NEW.description,
            "options", NEW.options),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_role_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `mrs_role` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_role",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "derived_from_role_id", OLD.derived_from_role_id,
            "specific_to_service_id", OLD.specific_to_service_id,
            "caption", OLD.caption,
            "description", OLD.description,
            "options", OLD.options),
        JSON_OBJECT(
            "id", NEW.id,
            "derived_from_role_id", NEW.derived_from_role_id,
            "specific_to_service_id", NEW.specific_to_service_id,
            "caption", NEW.caption,
            "description", NEW.description,
            "options", NEW.options),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_role_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `mrs_role` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_role",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "derived_from_role_id", OLD.derived_from_role_id,
            "specific_to_service_id", OLD.specific_to_service_id,
            "caption", OLD.caption,
            "description", OLD.description,
            "options", OLD.options),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_has_role_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `mrs_user_has_role` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_has_role",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "user_id", NEW.user_id,
            "role_id", NEW.role_id,
            "comments", NEW.comments,
            "options", NEW.options),
        NULL,
        NEW.user_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_has_role_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `mrs_user_has_role` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_has_role",
        "UPDATE",
        JSON_OBJECT(
            "user_id", OLD.user_id,
            "role_id", OLD.role_id,
            "comments", OLD.comments,
            "options", OLD.options),
        JSON_OBJECT(
            "user_id", NEW.user_id,
            "role_id", NEW.role_id,
            "comments", NEW.comments,
            "options", NEW.options),
        OLD.user_id,
        NEW.user_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_has_role_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `mrs_user_has_role` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_has_role",
        "DELETE",
        JSON_OBJECT(
            "user_id", OLD.user_id,
            "role_id", OLD.role_id,
            "comments", OLD.comments,
            "options", OLD.options),
        NULL,
        OLD.user_id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_hierarchy_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `mrs_user_hierarchy` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_hierarchy",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "user_id", NEW.user_id,
            "reporting_to_user_id", NEW.reporting_to_user_id,
            "user_hierarchy_type_id", NEW.user_hierarchy_type_id,
            "options", NEW.options),
        NULL,
        NEW.user_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_hierarchy_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `mrs_user_hierarchy` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_hierarchy",
        "UPDATE",
        JSON_OBJECT(
            "user_id", OLD.user_id,
            "reporting_to_user_id", OLD.reporting_to_user_id,
            "user_hierarchy_type_id", OLD.user_hierarchy_type_id,
            "options", OLD.options),
        JSON_OBJECT(
            "user_id", NEW.user_id,
            "reporting_to_user_id", NEW.reporting_to_user_id,
            "user_hierarchy_type_id", NEW.user_hierarchy_type_id,
            "options", NEW.options),
        OLD.user_id,
        NEW.user_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_hierarchy_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `mrs_user_hierarchy` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_hierarchy",
        "DELETE",
        JSON_OBJECT(
            "user_id", OLD.user_id,
            "reporting_to_user_id", OLD.reporting_to_user_id,
            "user_hierarchy_type_id", OLD.user_hierarchy_type_id,
            "options", OLD.options),
        NULL,
        OLD.user_id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_hierarchy_type_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `mrs_user_hierarchy_type` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_hierarchy_type",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "caption", NEW.caption,
            "description", NEW.description,
            "specific_to_service_id", NEW.specific_to_service_id,
            "options", NEW.options),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_hierarchy_type_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `mrs_user_hierarchy_type` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_hierarchy_type",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "caption", OLD.caption,
            "description", OLD.description,
            "specific_to_service_id", OLD.specific_to_service_id,
            "options", OLD.options),
        JSON_OBJECT(
            "id", NEW.id,
            "caption", NEW.caption,
            "description", NEW.description,
            "specific_to_service_id", NEW.specific_to_service_id,
            "options", NEW.options),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_hierarchy_type_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `mrs_user_hierarchy_type` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_hierarchy_type",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "caption", OLD.caption,
            "description", OLD.description,
            "specific_to_service_id", OLD.specific_to_service_id,
            "options", OLD.options),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_privilege_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `mrs_privilege` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_privilege",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "role_id", NEW.role_id,
            "crud_operations", NEW.crud_operations,
            "service_id", NEW.service_id,
            "db_schema_id", NEW.db_schema_id,
            "db_object_id", NEW.db_object_id,
            "options", NEW.options),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_privilege_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `mrs_privilege` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_privilege",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "role_id", OLD.role_id,
            "crud_operations", OLD.crud_operations,
            "service_id", OLD.service_id,
            "db_schema_id", OLD.db_schema_id,
            "db_object_id", OLD.db_object_id,
            "options", OLD.options),
        JSON_OBJECT(
            "id", NEW.id,
            "role_id", NEW.role_id,
            "crud_operations", NEW.crud_operations,
            "service_id", NEW.service_id,
            "db_schema_id", NEW.db_schema_id,
            "db_object_id", NEW.db_object_id,
            "options", NEW.options),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_privilege_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `mrs_privilege` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_privilege",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "role_id", OLD.role_id,
            "crud_operations", OLD.crud_operations,
            "service_id", OLD.service_id,
            "db_schema_id", OLD.db_schema_id,
            "db_object_id", OLD.db_object_id,
            "options", OLD.options),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_group_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `mrs_user_group` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_group",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "specific_to_service_id", NEW.specific_to_service_id,
            "caption", NEW.caption,
            "description", NEW.description,
            "options", NEW.options),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_group_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `mrs_user_group` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_group",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "specific_to_service_id", OLD.specific_to_service_id,
            "caption", OLD.caption,
            "description", OLD.description,
            "options", OLD.options),
        JSON_OBJECT(
            "id", NEW.id,
            "specific_to_service_id", NEW.specific_to_service_id,
            "caption", NEW.caption,
            "description", NEW.description,
            "options", NEW.options),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_group_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `mrs_user_group` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_group",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "specific_to_service_id", OLD.specific_to_service_id,
            "caption", OLD.caption,
            "description", OLD.description,
            "options", OLD.options),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_group_has_role_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `mrs_user_group_has_role` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_group_has_role",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "user_group_id", NEW.user_group_id,
            "role_id", NEW.role_id,
            "options", NEW.options),
        NULL,
        NEW.user_group_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_group_has_role_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `mrs_user_group_has_role` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_group_has_role",
        "UPDATE",
        JSON_OBJECT(
            "user_group_id", OLD.user_group_id,
            "role_id", OLD.role_id,
            "options", OLD.options),
        JSON_OBJECT(
            "user_group_id", NEW.user_group_id,
            "role_id", NEW.role_id,
            "options", NEW.options),
        OLD.user_group_id,
        NEW.user_group_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_group_has_role_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `mrs_user_group_has_role` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_group_has_role",
        "DELETE",
        JSON_OBJECT(
            "user_group_id", OLD.user_group_id,
            "role_id", OLD.role_id,
            "options", OLD.options),
        NULL,
        OLD.user_group_id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_has_group_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `mrs_user_has_group` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_has_group",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "user_id", NEW.user_id,
            "user_group_id", NEW.user_group_id,
            "comments", NEW.comments,
            "options", NEW.options),
        NULL,
        NEW.user_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_has_group_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `mrs_user_has_group` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_has_group",
        "UPDATE",
        JSON_OBJECT(
            "user_id", OLD.user_id,
            "user_group_id", OLD.user_group_id,
            "comments", OLD.comments,
            "options", OLD.options),
        JSON_OBJECT(
            "user_id", NEW.user_id,
            "user_group_id", NEW.user_group_id,
            "comments", NEW.comments,
            "options", NEW.options),
        OLD.user_id,
        NEW.user_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_has_group_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `mrs_user_has_group` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_has_group",
        "DELETE",
        JSON_OBJECT(
            "user_id", OLD.user_id,
            "user_group_id", OLD.user_group_id,
            "comments", OLD.comments,
            "options", OLD.options),
        NULL,
        OLD.user_id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_group_hierarchy_type_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `mrs_group_hierarchy_type` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_group_hierarchy_type",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "caption", NEW.caption,
            "description", NEW.description,
            "options", NEW.options),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_group_hierarchy_type_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `mrs_group_hierarchy_type` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_group_hierarchy_type",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "caption", OLD.caption,
            "description", OLD.description,
            "options", OLD.options),
        JSON_OBJECT(
            "id", NEW.id,
            "caption", NEW.caption,
            "description", NEW.description,
            "options", NEW.options),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_group_hierarchy_type_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `mrs_group_hierarchy_type` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_group_hierarchy_type",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "caption", OLD.caption,
            "description", OLD.description,
            "options", OLD.options),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_group_hierarchy_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `mrs_user_group_hierarchy` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_group_hierarchy",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "user_group_id", NEW.user_group_id,
            "parent_group_id", NEW.parent_group_id,
            "group_hierarchy_type_id", NEW.group_hierarchy_type_id,
            "level", NEW.level,
            "options", NEW.options),
        NULL,
        NEW.user_group_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_group_hierarchy_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `mrs_user_group_hierarchy` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_group_hierarchy",
        "UPDATE",
        JSON_OBJECT(
            "user_group_id", OLD.user_group_id,
            "parent_group_id", OLD.parent_group_id,
            "group_hierarchy_type_id", OLD.group_hierarchy_type_id,
            "level", OLD.level,
            "options", OLD.options),
        JSON_OBJECT(
            "user_group_id", NEW.user_group_id,
            "parent_group_id", NEW.parent_group_id,
            "group_hierarchy_type_id", NEW.group_hierarchy_type_id,
            "level", NEW.level,
            "options", NEW.options),
        OLD.user_group_id,
        NEW.user_group_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_user_group_hierarchy_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `mrs_user_group_hierarchy` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_user_group_hierarchy",
        "DELETE",
        JSON_OBJECT(
            "user_group_id", OLD.user_group_id,
            "parent_group_id", OLD.parent_group_id,
            "group_hierarchy_type_id", OLD.group_hierarchy_type_id,
            "level", OLD.level,
            "options", OLD.options),
        NULL,
        OLD.user_group_id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_db_object_row_group_security_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `mrs_db_object_row_group_security` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_db_object_row_group_security",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "db_object_id", NEW.db_object_id,
            "group_hierarchy_type_id", NEW.group_hierarchy_type_id,
            "row_group_ownership_column", NEW.row_group_ownership_column,
            "level", NEW.level,
            "match_level", NEW.match_level,
            "options", NEW.options),
        NULL,
        NEW.db_object_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_db_object_row_group_security_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `mrs_db_object_row_group_security` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_db_object_row_group_security",
        "UPDATE",
        JSON_OBJECT(
            "db_object_id", OLD.db_object_id,
            "group_hierarchy_type_id", OLD.group_hierarchy_type_id,
            "row_group_ownership_column", OLD.row_group_ownership_column,
            "level", OLD.level,
            "match_level", OLD.match_level,
            "options", OLD.options),
        JSON_OBJECT(
            "db_object_id", NEW.db_object_id,
            "group_hierarchy_type_id", NEW.group_hierarchy_type_id,
            "row_group_ownership_column", NEW.row_group_ownership_column,
            "level", NEW.level,
            "match_level", NEW.match_level,
            "options", NEW.options),
        OLD.db_object_id,
        NEW.db_object_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`mrs_db_object_row_group_security_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `mrs_db_object_row_group_security` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "mrs_db_object_row_group_security",
        "DELETE",
        JSON_OBJECT(
            "db_object_id", OLD.db_object_id,
            "group_hierarchy_type_id", OLD.group_hierarchy_type_id,
            "row_group_ownership_column", OLD.row_group_ownership_column,
            "level", OLD.level,
            "match_level", OLD.match_level,
            "options", OLD.options),
        NULL,
        OLD.db_object_id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`object_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `object` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "object",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "db_object_id", NEW.db_object_id,
            "name", NEW.name,
            "kind", NEW.kind,
            "position", NEW.position,
            "row_ownership_field_id", NEW.row_ownership_field_id,
            "options", NEW.options,
            "sdk_options", NEW.sdk_options,
            "comments", NEW.comments),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`object_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `object` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "object",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "db_object_id", OLD.db_object_id,
            "name", OLD.name,
            "kind", OLD.kind,
            "position", OLD.position,
            "row_ownership_field_id", OLD.row_ownership_field_id,
            "options", OLD.options,
            "sdk_options", OLD.sdk_options,
            "comments", OLD.comments),
        JSON_OBJECT(
            "id", NEW.id,
            "db_object_id", NEW.db_object_id,
            "name", NEW.name,
            "kind", NEW.kind,
            "position", NEW.position,
            "row_ownership_field_id", NEW.row_ownership_field_id,
            "options", NEW.options,
            "sdk_options", NEW.sdk_options,
            "comments", NEW.comments),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`object_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `object` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "object",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "db_object_id", OLD.db_object_id,
            "name", OLD.name,
            "kind", OLD.kind,
            "position", OLD.position,
            "row_ownership_field_id", OLD.row_ownership_field_id,
            "options", OLD.options,
            "sdk_options", OLD.sdk_options,
            "comments", OLD.comments),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`object_field_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `object_field` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "object_field",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "object_id", NEW.object_id,
            "parent_reference_id", NEW.parent_reference_id,
            "represents_reference_id", NEW.represents_reference_id,
            "name", NEW.name,
            "position", NEW.position,
            "db_column", NEW.db_column,
            "enabled", NEW.enabled,
            "allow_filtering", NEW.allow_filtering,
            "allow_sorting", NEW.allow_sorting,
            "no_check", NEW.no_check,
            "no_update", NEW.no_update,
            "options", NEW.options,
            "sdk_options", NEW.sdk_options,
            "comments", NEW.comments),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`object_field_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `object_field` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "object_field",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "object_id", OLD.object_id,
            "parent_reference_id", OLD.parent_reference_id,
            "represents_reference_id", OLD.represents_reference_id,
            "name", OLD.name,
            "position", OLD.position,
            "db_column", OLD.db_column,
            "enabled", OLD.enabled,
            "allow_filtering", OLD.allow_filtering,
            "allow_sorting", OLD.allow_sorting,
            "no_check", OLD.no_check,
            "no_update", OLD.no_update,
            "options", OLD.options,
            "sdk_options", OLD.sdk_options,
            "comments", OLD.comments),
        JSON_OBJECT(
            "id", NEW.id,
            "object_id", NEW.object_id,
            "parent_reference_id", NEW.parent_reference_id,
            "represents_reference_id", NEW.represents_reference_id,
            "name", NEW.name,
            "position", NEW.position,
            "db_column", NEW.db_column,
            "enabled", NEW.enabled,
            "allow_filtering", NEW.allow_filtering,
            "allow_sorting", NEW.allow_sorting,
            "no_check", NEW.no_check,
            "no_update", NEW.no_update,
            "options", NEW.options,
            "sdk_options", NEW.sdk_options,
            "comments", NEW.comments),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`object_field_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `object_field` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "object_field",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "object_id", OLD.object_id,
            "parent_reference_id", OLD.parent_reference_id,
            "represents_reference_id", OLD.represents_reference_id,
            "name", OLD.name,
            "position", OLD.position,
            "db_column", OLD.db_column,
            "enabled", OLD.enabled,
            "allow_filtering", OLD.allow_filtering,
            "allow_sorting", OLD.allow_sorting,
            "no_check", OLD.no_check,
            "no_update", OLD.no_update,
            "options", OLD.options,
            "sdk_options", OLD.sdk_options,
            "comments", OLD.comments),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`object_reference_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `object_reference` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "object_reference",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "id", NEW.id,
            "reduce_to_value_of_field_id", NEW.reduce_to_value_of_field_id,
            "row_ownership_field_id", NEW.row_ownership_field_id,
            "reference_mapping", NEW.reference_mapping,
            "unnest", NEW.unnest,
            "options", NEW.options,
            "sdk_options", NEW.sdk_options,
            "comments", NEW.comments),
        NULL,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`object_reference_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `object_reference` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "object_reference",
        "UPDATE",
        JSON_OBJECT(
            "id", OLD.id,
            "reduce_to_value_of_field_id", OLD.reduce_to_value_of_field_id,
            "row_ownership_field_id", OLD.row_ownership_field_id,
            "reference_mapping", OLD.reference_mapping,
            "unnest", OLD.unnest,
            "options", OLD.options,
            "sdk_options", OLD.sdk_options,
            "comments", OLD.comments),
        JSON_OBJECT(
            "id", NEW.id,
            "reduce_to_value_of_field_id", NEW.reduce_to_value_of_field_id,
            "row_ownership_field_id", NEW.row_ownership_field_id,
            "reference_mapping", NEW.reference_mapping,
            "unnest", NEW.unnest,
            "options", NEW.options,
            "sdk_options", NEW.sdk_options,
            "comments", NEW.comments),
        OLD.id,
        NEW.id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`object_reference_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `object_reference` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "object_reference",
        "DELETE",
        JSON_OBJECT(
            "id", OLD.id,
            "reduce_to_value_of_field_id", OLD.reduce_to_value_of_field_id,
            "row_ownership_field_id", OLD.row_ownership_field_id,
            "reference_mapping", OLD.reference_mapping,
            "unnest", OLD.unnest,
            "options", OLD.options,
            "sdk_options", OLD.sdk_options,
            "comments", OLD.comments),
        NULL,
        OLD.id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`service_has_auth_app_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `service_has_auth_app` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "service_has_auth_app",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "service_id", NEW.service_id,
            "auth_app_id", NEW.auth_app_id,
            "options", NEW.options),
        NULL,
        NEW.service_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`service_has_auth_app_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `service_has_auth_app` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "service_has_auth_app",
        "UPDATE",
        JSON_OBJECT(
            "service_id", OLD.service_id,
            "auth_app_id", OLD.auth_app_id,
            "options", OLD.options),
        JSON_OBJECT(
            "service_id", NEW.service_id,
            "auth_app_id", NEW.auth_app_id,
            "options", NEW.options),
        OLD.service_id,
        NEW.service_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`service_has_auth_app_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `service_has_auth_app` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "service_has_auth_app",
        "DELETE",
        JSON_OBJECT(
            "service_id", OLD.service_id,
            "auth_app_id", OLD.auth_app_id,
            "options", OLD.options),
        NULL,
        OLD.service_id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`content_set_has_obj_def_AFTER_INSERT_AUDIT_LOG` AFTER INSERT ON `content_set_has_obj_def` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "content_set_has_obj_def",
        "INSERT",
        NULL,
        JSON_OBJECT(
            "content_set_id", NEW.content_set_id,
            "db_object_id", NEW.db_object_id,
            "method_type", NEW.method_type,
            "priority", NEW.priority,
            "language", NEW.language,
            "class_name", NEW.class_name,
            "method_name", NEW.method_name,
            "comments", NEW.comments,
            "options", NEW.options),
        NULL,
        NEW.content_set_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`content_set_has_obj_def_AFTER_UPDATE_AUDIT_LOG` AFTER UPDATE ON `content_set_has_obj_def` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "content_set_has_obj_def",
        "UPDATE",
        JSON_OBJECT(
            "content_set_id", OLD.content_set_id,
            "db_object_id", OLD.db_object_id,
            "method_type", OLD.method_type,
            "priority", OLD.priority,
            "language", OLD.language,
            "class_name", OLD.class_name,
            "method_name", OLD.method_name,
            "comments", OLD.comments,
            "options", OLD.options),
        JSON_OBJECT(
            "content_set_id", NEW.content_set_id,
            "db_object_id", NEW.db_object_id,
            "method_type", NEW.method_type,
            "priority", NEW.priority,
            "language", NEW.language,
            "class_name", NEW.class_name,
            "method_name", NEW.method_name,
            "comments", NEW.comments,
            "options", NEW.options),
        OLD.content_set_id,
        NEW.content_set_id,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

CREATE TRIGGER `mysql_rest_service_metadata`.`content_set_has_obj_def_AFTER_DELETE_AUDIT_LOG` AFTER DELETE ON `content_set_has_obj_def` FOR EACH ROW
BEGIN
	INSERT INTO `mysql_rest_service_metadata`.`audit_log` (
		table_name, dml_type, old_row_data, new_row_data, old_row_id, new_row_id, changed_by, changed_at)
	VALUES (
        "content_set_has_obj_def",
        "DELETE",
        JSON_OBJECT(
            "content_set_id", OLD.content_set_id,
            "db_object_id", OLD.db_object_id,
            "method_type", OLD.method_type,
            "priority", OLD.priority,
            "language", OLD.language,
            "class_name", OLD.class_name,
            "method_name", OLD.method_name,
            "comments", OLD.comments,
            "options", OLD.options),
        NULL,
        OLD.content_set_id,
        NULL,
        CURRENT_USER(),
        CURRENT_TIMESTAMP
    );
END$$

DELIMITER ;

-- -----------------------------------------------------
-- Create roles for the MySQL REST Service

-- The mysql_rest_service_admin ROLE allows to fully manage the REST services
-- The mysql_rest_service_schema_admin ROLE allows to manage the database schemas assigned to REST services
-- The mysql_rest_service_dev ROLE allows to develop new REST objects for given REST services and upload static files
-- The mysql_rest_service_meta_provider ROLE is used by the MySQL Router to read the mrs metadata and make inserts into the auth_user table
-- The mysql_rest_service_data_provider ROLE is used by the MySQL Router to read the actual schema data that is exposed via REST

CREATE ROLE IF NOT EXISTS 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider', 'mysql_rest_service_data_provider';

-- Allow the 'mysql_rest_service_data_provider' role to create temporary tables
GRANT CREATE TEMPORARY TABLES ON *.*
    TO 'mysql_rest_service_data_provider';

-- `mysql_rest_service_metadata`.`schema_version`
GRANT SELECT ON `mysql_rest_service_metadata`.`schema_version`
	TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`audit_log`
GRANT SELECT ON `mysql_rest_service_metadata`.`audit_log`
	TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider';

-- -----------------------------------------------------
-- Config

-- `mysql_rest_service_metadata`.`config`
GRANT SELECT, UPDATE
	ON `mysql_rest_service_metadata`.`config`
    TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin';
GRANT SELECT ON `mysql_rest_service_metadata`.`config`
	TO 'mysql_rest_service_meta_provider', 'mysql_rest_service_dev';

-- `mysql_rest_service_metadata`.`redirect`
GRANT SELECT, INSERT, UPDATE, DELETE
	ON `mysql_rest_service_metadata`.`redirect`
    TO 'mysql_rest_service_admin';
GRANT SELECT ON `mysql_rest_service_metadata`.`redirect`
	TO 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider';

-- -----------------------------------------------------
-- Service

-- `mysql_rest_service_metadata`.`url_host`
GRANT SELECT, INSERT, UPDATE, DELETE
	ON `mysql_rest_service_metadata`.`url_host`
    TO 'mysql_rest_service_admin';
GRANT SELECT ON `mysql_rest_service_metadata`.`url_host`
	TO 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`url_host_alias`
GRANT SELECT, INSERT, DELETE
	ON `mysql_rest_service_metadata`.`url_host_alias`
    TO 'mysql_rest_service_admin';
GRANT SELECT ON `mysql_rest_service_metadata`.`url_host_alias`
	TO 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`service`
GRANT SELECT, INSERT, UPDATE, DELETE
	ON `mysql_rest_service_metadata`.`service`
    TO 'mysql_rest_service_admin';
GRANT SELECT ON `mysql_rest_service_metadata`.`service`
	TO 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider';

-- -----------------------------------------------------
-- Schema Objects

-- `mysql_rest_service_metadata`.`db_schema`
GRANT SELECT, INSERT, UPDATE, DELETE
	ON `mysql_rest_service_metadata`.`db_schema`
    TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin';
GRANT SELECT ON `mysql_rest_service_metadata`.`db_schema`
	TO 'mysql_rest_service_meta_provider', 'mysql_rest_service_dev';

-- `mysql_rest_service_metadata`.`db_object`
GRANT SELECT, INSERT, UPDATE, DELETE
	ON `mysql_rest_service_metadata`.`db_object`
	TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';
GRANT SELECT ON `mysql_rest_service_metadata`.`db_object`
	TO 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`mrs_db_object_row_group_security`
GRANT SELECT, INSERT, UPDATE, DELETE
	ON `mysql_rest_service_metadata`.`mrs_db_object_row_group_security`
	TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';
GRANT SELECT ON `mysql_rest_service_metadata`.`mrs_db_object_row_group_security`
	TO 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`object`
GRANT SELECT, INSERT, UPDATE, DELETE
	ON `mysql_rest_service_metadata`.`object`
    TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';
GRANT SELECT ON `mysql_rest_service_metadata`.`object`
	TO 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`object_field`
GRANT SELECT, INSERT, UPDATE, DELETE
	ON `mysql_rest_service_metadata`.`object_field`
    TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';
GRANT SELECT ON `mysql_rest_service_metadata`.`object_field`
	TO 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`object_reference`
GRANT SELECT, INSERT, UPDATE, DELETE
	ON `mysql_rest_service_metadata`.`object_reference`
    TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';
GRANT SELECT ON `mysql_rest_service_metadata`.`object_reference`
	TO 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`table_columns_with_references`
GRANT SELECT
	ON `mysql_rest_service_metadata`.`table_columns_with_references`
    TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`object_fields_with_references`
GRANT SELECT
	ON `mysql_rest_service_metadata`.`object_fields_with_references`
    TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider';

-- -----------------------------------------------------
-- Static Content

-- `mysql_rest_service_metadata`.`content_set`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`content_set`
	TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';
GRANT SELECT ON `mysql_rest_service_metadata`.`content_set`
	TO 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`content_file`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`content_file`
    TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';
GRANT SELECT ON `mysql_rest_service_metadata`.`content_file`
	TO 'mysql_rest_service_meta_provider';


-- `mysql_rest_service_metadata`.`content_set_has_obj_def`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`content_set_has_obj_def`
    TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';
GRANT SELECT ON `mysql_rest_service_metadata`.`content_set_has_obj_def`
	TO 'mysql_rest_service_meta_provider';

-- -----------------------------------------------------
-- User Authentication

-- `mysql_rest_service_metadata`.`auth_app`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`auth_app`
    TO 'mysql_rest_service_admin';
GRANT SELECT ON `mysql_rest_service_metadata`.`auth_app`
	TO 'mysql_rest_service_meta_provider', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';

-- `mysql_rest_service_metadata`.`service_has_auth_app`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`service_has_auth_app`
    TO 'mysql_rest_service_admin';
GRANT SELECT ON `mysql_rest_service_metadata`.`service_has_auth_app`
	TO 'mysql_rest_service_meta_provider', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';

-- `mysql_rest_service_metadata`.`auth_vendor`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`auth_vendor`
    TO 'mysql_rest_service_admin';
GRANT SELECT ON `mysql_rest_service_metadata`.`auth_vendor`
	TO 'mysql_rest_service_meta_provider', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';

-- `mysql_rest_service_metadata`.`mrs_user`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`mrs_user`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT ON `mysql_rest_service_metadata`.`mrs_user`
	TO 'mysql_rest_service_meta_provider';
GRANT SELECT ON `mysql_rest_service_metadata`.`mrs_user`
	TO 'mysql_rest_service_data_provider';

-- -----------------------------------------------------
-- User Hierarchy

-- `mysql_rest_service_metadata`.`mrs_user_hierarchy`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`mrs_user_hierarchy`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT ON `mysql_rest_service_metadata`.`mrs_user_hierarchy`
	TO 'mysql_rest_service_meta_provider';
GRANT SELECT ON `mysql_rest_service_metadata`.`mrs_user_hierarchy`
	TO 'mysql_rest_service_data_provider';

-- `mysql_rest_service_metadata`.`mrs_user_hierarchy_type`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`mrs_user_hierarchy_type`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT ON `mysql_rest_service_metadata`.`mrs_user_hierarchy_type`
	TO 'mysql_rest_service_meta_provider';

-- -----------------------------------------------------
-- User Roles

-- `mysql_rest_service_metadata`.`mrs_user_has_role`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`mrs_user_has_role`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT ON `mysql_rest_service_metadata`.`mrs_user_has_role`
	TO 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`mrs_role`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`mrs_role`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT ON `mysql_rest_service_metadata`.`mrs_role`
	TO 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`mrs_privilege`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`mrs_privilege`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT ON `mysql_rest_service_metadata`.`mrs_privilege`
	TO 'mysql_rest_service_meta_provider';

-- -----------------------------------------------------
-- User Group Management

-- `mysql_rest_service_metadata`.`mrs_user_has_group`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`mrs_user_has_group`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT ON `mysql_rest_service_metadata`.`mrs_user_has_group`
	TO 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`mrs_user_group`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`mrs_user_group`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT ON `mysql_rest_service_metadata`.`mrs_user_group`
	TO 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`mrs_user_group_has_role`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`mrs_user_group_has_role`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT ON `mysql_rest_service_metadata`.`mrs_user_group_has_role`
	TO 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`mrs_group_hierarchy_type`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`mrs_group_hierarchy_type`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT ON `mysql_rest_service_metadata`.`mrs_group_hierarchy_type`
	TO 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`mrs_user_group_hierarchy`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`mrs_user_group_hierarchy`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT ON `mysql_rest_service_metadata`.`mrs_user_group_hierarchy`
	TO 'mysql_rest_service_meta_provider';
GRANT SELECT ON `mysql_rest_service_metadata`.`mrs_user_group_hierarchy`
	TO 'mysql_rest_service_data_provider';

-- -----------------------------------------------------
-- Router Management

-- `mysql_rest_service_metadata`.`router`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`router`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT, UPDATE ON `mysql_rest_service_metadata`.`router`
	TO 'mysql_rest_service_meta_provider';
GRANT SELECT
    ON `mysql_rest_service_metadata`.`router`
    TO 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';

-- `mysql_rest_service_metadata`.`router_status`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`router_status`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT, UPDATE ON `mysql_rest_service_metadata`.`router_status`
	TO 'mysql_rest_service_meta_provider';
GRANT SELECT ON `mysql_rest_service_metadata`.`router_status`
	TO 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';

-- `mysql_rest_service_metadata`.`router_general_log`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`router_general_log`
    TO 'mysql_rest_service_admin';
GRANT INSERT ON `mysql_rest_service_metadata`.`router_general_log`
	TO 'mysql_rest_service_meta_provider';
GRANT SELECT ON `mysql_rest_service_metadata`.`router_general_log`
	TO 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';

-- `mysql_rest_service_metadata`.`router_session`
GRANT SELECT, INSERT, UPDATE, DELETE
    ON `mysql_rest_service_metadata`.`router_session`
    TO 'mysql_rest_service_admin';
GRANT SELECT, INSERT ON `mysql_rest_service_metadata`.`router_session`
	TO 'mysql_rest_service_meta_provider';
GRANT SELECT ON `mysql_rest_service_metadata`.`router_session`
	TO 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev';

-- `mysql_rest_service_metadata`.`router_services`
GRANT SELECT ON `mysql_rest_service_metadata`.`router_services`
    TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider';

-- -----------------------------------------------------
-- Procedures

-- `mysql_rest_service_metadata`.`get_sequence_id`

GRANT EXECUTE ON FUNCTION `mysql_rest_service_metadata`.`get_sequence_id`
	TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider', 'mysql_rest_service_data_provider';

-- -----------------------------------------------------
-- Views

-- `mysql_rest_service_metadata`.`mrs_user_schema_version`

GRANT SELECT
  ON `mysql_rest_service_metadata`.`mrs_user_schema_version`
  TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`table_columns_with_references`

GRANT SELECT
  ON `mysql_rest_service_metadata`.`table_columns_with_references`
  TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider';

-- `mysql_rest_service_metadata`.`object_fields_with_references`

GRANT SELECT
  ON `mysql_rest_service_metadata`.`object_fields_with_references`
  TO 'mysql_rest_service_admin', 'mysql_rest_service_schema_admin', 'mysql_rest_service_dev', 'mysql_rest_service_meta_provider';

-- -----------------------------------------------------
-- Set the schema_version VIEW to the correct version at the very end

CREATE OR REPLACE SQL SECURITY INVOKER VIEW `mysql_rest_service_metadata`.`schema_version` (major, minor, patch) AS SELECT 3, 0, 0;

-- Copyright (c) 2022, 2024, Oracle and/or its affiliates.
